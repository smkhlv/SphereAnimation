import SwiftUI
import MetalKit

#if os(iOS) || os(tvOS)
import UIKit

struct MetalViewRepresentable: UIViewRepresentable {
    let sphereConfigs: [SphereConfig]

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = true
        context.coordinator.setup(mtkView: mtkView, sphereConfigs: sphereConfigs)
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.updateSphereConfigs(sphereConfigs)
    }

    func makeCoordinator() -> MetalRenderer {
        MetalRenderer()
    }
}

#elseif os(macOS)
import AppKit

struct MetalViewRepresentable: NSViewRepresentable {
    let sphereConfigs: [SphereConfig]

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = true
        context.coordinator.setup(mtkView: mtkView, sphereConfigs: sphereConfigs)
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.updateSphereConfigs(sphereConfigs)
    }

    func makeCoordinator() -> MetalRenderer {
        MetalRenderer()
    }
}
#endif
