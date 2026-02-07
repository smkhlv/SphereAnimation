import MetalKit
import SwiftUI
import CSphereAnimationTypes

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var sphereGeometries: [Float: SphereGeometry] = [:]  // Cache geometries by radius
    private var animator: MetalAnimationCoordinator?

    private var lastUpdateTime: CFTimeInterval = 0
    private var sphereConfigs: [SphereConfig] = []

    /// The most recently rendered frame texture.
    public private(set) var currentTexture: MTLTexture?
    private var offscreenTexture: MTLTexture?

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not supported on this device")
        }

        self.device = device
        self.commandQueue = commandQueue
        super.init()
    }

    func setup(mtkView: MTKView, sphereConfigs: [SphereConfig]) {
        self.sphereConfigs = sphereConfigs

        mtkView.device = device
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false

        setupPipeline()
        setupGeometries()
        setupAnimator(viewSize: mtkView.bounds.size)

        lastUpdateTime = CACurrentMediaTime()
    }

    private func setupPipeline() {
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.module) else {
            fatalError("Could not create Metal library")
        }

        let vertexFunction = library.makeFunction(name: "sphereVertexShader")
        let fragmentFunction = library.makeFunction(name: "sphereFragmentShader")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Enable blending for smooth edges
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }

    private func setupGeometries() {
        // Create unique geometries for each radius used in configs
        let uniqueRadii = Set(sphereConfigs.map { $0.radius })

        for radius in uniqueRadii {
            sphereGeometries[radius] = SphereGeometry.createIcosphere(
                device: device,
                radius: radius,
                subdivisions: 2
            )
        }
    }

    private func setupAnimator(viewSize: CGSize) {
        animator = MetalAnimationCoordinator(viewBounds: viewSize, sphereConfigs: sphereConfigs)
    }

    func updateSphereConfigs(_ newConfigs: [SphereConfig]) {
        let oldConfigs = self.sphereConfigs
        self.sphereConfigs = newConfigs

        // Update animator configs
        animator?.updateSphereConfigs(newConfigs)

        // Check if we need new geometries
        let oldRadii = Set(oldConfigs.map { $0.radius })
        let newRadii = Set(newConfigs.map { $0.radius })

        if oldRadii != newRadii {
            setupGeometries()
        }
    }

    // MARK: - MTKViewDelegate

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Use view.bounds.size (in points) not drawable size (in pixels)
        animator?.updateViewBounds(view.bounds.size)
    }

    public func draw(in view: MTKView) {
        // Update view bounds every frame to ensure animator has correct boundaries
        animator?.updateViewBounds(view.bounds.size)

        // Calculate delta time
        let currentTime = CACurrentMediaTime()
        let deltaTime = Float(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        // Update animation
        animator?.update(deltaTime: deltaTime)

        guard let drawable = view.currentDrawable,
              let pipelineState = pipelineState,
              let animator = animator else {
            return
        }

        let drawableSize = view.drawableSize
        let viewSize = view.bounds.size

        // Ensure offscreen texture matches drawable size
        updateOffscreenTexture(width: Int(drawableSize.width), height: Int(drawableSize.height))
        guard let offscreen = offscreenTexture else { return }

        // Create render pass for offscreen texture
        let offscreenPassDescriptor = MTLRenderPassDescriptor()
        offscreenPassDescriptor.colorAttachments[0].texture = offscreen
        offscreenPassDescriptor.colorAttachments[0].loadAction = .clear
        offscreenPassDescriptor.colorAttachments[0].storeAction = .store
        offscreenPassDescriptor.colorAttachments[0].clearColor = view.clearColor

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: offscreenPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)

        // Draw each sphere separately
        for sphereState in animator.spheres {
            guard let geometry = sphereGeometries[sphereState.config.radius] else {
                continue
            }

            var vertexUniforms = createVertexUniforms(
                viewSize: viewSize,
                spherePosition: sphereState.position,
                sphereRadius: sphereState.config.radius
            )

            let colors = sphereState.config.colors.map { $0.color }
            var fragmentUniforms = createFragmentUniforms(
                colors: colors,
                time: sphereState.currentTime,
                cycleDuration: animator.colorCycleDuration,
                glowIntensity: sphereState.config.glowIntensity
            )

            renderEncoder.setVertexBuffer(geometry.vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: 0)

            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: geometry.indexCount,
                indexType: .uint16,
                indexBuffer: geometry.indexBuffer,
                indexBufferOffset: 0
            )
        }

        renderEncoder.endEncoding()

        // Blit offscreen texture to drawable for on-screen display
        if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitEncoder.copy(from: offscreen,
                           sourceSlice: 0,
                           sourceLevel: 0,
                           sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                           sourceSize: MTLSize(width: offscreen.width, height: offscreen.height, depth: 1),
                           to: drawable.texture,
                           destinationSlice: 0,
                           destinationLevel: 0,
                           destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
            blitEncoder.endEncoding()
        }

        // Expose the offscreen texture for external consumers
        self.currentTexture = offscreen

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func updateOffscreenTexture(width: Int, height: Int) {
        if let existing = offscreenTexture,
           existing.width == width,
           existing.height == height {
            return
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private

        offscreenTexture = device.makeTexture(descriptor: descriptor)
    }

    // MARK: - Helper Methods

    private func createVertexUniforms(
        viewSize: CGSize,
        spherePosition: SIMD2<Float>,
        sphereRadius: Float
    ) -> VertexUniforms {
        // Create orthographic projection for 2D-style rendering in 3D space
        let width = Float(viewSize.width)
        let height = Float(viewSize.height)

        // Orthographic projection matrix
        let left: Float = 0
        let right = width
        let bottom = height
        let top: Float = 0
        let near: Float = -100
        let far: Float = 100

        let projectionMatrix = simd_float4x4(
            SIMD4(2 / (right - left), 0, 0, 0),
            SIMD4(0, 2 / (top - bottom), 0, 0),
            SIMD4(0, 0, -2 / (far - near), 0),
            SIMD4(-(right + left) / (right - left), -(top + bottom) / (top - bottom), -(far + near) / (far - near), 1)
        )

        // Position sphere at 2D screen coordinates
        let translationMatrix = matrix_identity_float4x4
        var modelMatrix = translationMatrix
        modelMatrix.columns.3.x = spherePosition.x
        modelMatrix.columns.3.y = spherePosition.y
        modelMatrix.columns.3.z = 0

        let cameraPosition = SIMD3<Float>(width / 2, height / 2, 100)

        return VertexUniforms(
            modelMatrix: modelMatrix,
            viewProjectionMatrix: projectionMatrix,
            cameraPosition: cameraPosition,
            spherePosition: spherePosition,
            sphereScale: sphereRadius  // Use actual sphere radius
        )
    }

    private func createFragmentUniforms(
        colors: [Color],
        time: Float,
        cycleDuration: Float,
        glowIntensity: Float
    ) -> FragmentUniforms {
        // Convert SwiftUI Colors to SIMD3
        let convertedColors: [SIMD3<Float>] = colors.prefix(10).map { color in
            #if canImport(UIKit)
            let platformColor = UIColor(color)
            #elseif canImport(AppKit)
            let platformColor = NSColor(color)
            #endif
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            platformColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            return SIMD3<Float>(Float(r), Float(g), Float(b))
        }

        // Pad with zeros if less than 10 colors
        var colorsTuple: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>,
                          SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) = (
            .zero, .zero, .zero, .zero, .zero,
            .zero, .zero, .zero, .zero, .zero
        )

        if convertedColors.count > 0 { colorsTuple.0 = convertedColors[0] }
        if convertedColors.count > 1 { colorsTuple.1 = convertedColors[1] }
        if convertedColors.count > 2 { colorsTuple.2 = convertedColors[2] }
        if convertedColors.count > 3 { colorsTuple.3 = convertedColors[3] }
        if convertedColors.count > 4 { colorsTuple.4 = convertedColors[4] }
        if convertedColors.count > 5 { colorsTuple.5 = convertedColors[5] }
        if convertedColors.count > 6 { colorsTuple.6 = convertedColors[6] }
        if convertedColors.count > 7 { colorsTuple.7 = convertedColors[7] }
        if convertedColors.count > 8 { colorsTuple.8 = convertedColors[8] }
        if convertedColors.count > 9 { colorsTuple.9 = convertedColors[9] }

        // Light position slightly above and to the right for nice highlights
        let lightPosition = SIMD3<Float>(100, 100, 150)

        return FragmentUniforms(
            colors: colorsTuple,
            colorCount: Int32(min(colors.count, 10)),
            time: time,
            lightPosition: lightPosition,
            colorCycleDuration: cycleDuration,
            glowIntensity: glowIntensity
        )
    }
}
