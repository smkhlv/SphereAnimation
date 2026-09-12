import Metal
import Testing
@testable import SphereAnimation

enum SphereTestSupport {
    static func device() throws -> MTLDevice {
        try #require(MTLCreateSystemDefaultDevice())
    }
}

extension SphereRenderedFrame {
    static func testFrame(
        onRelease: @escaping @Sendable () -> Void = {}
    ) throws -> SphereRenderedFrame {
        let device = try SphereTestSupport.device()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        return SphereRenderedFrame(
            texture: try #require(device.makeTexture(descriptor: descriptor)),
            readinessEvent: try #require(device.makeSharedEvent()),
            readinessValue: 1,
            onRelease: onRelease
        )
    }
}

extension SphereTexturePool {
    static func testPool(capacity: Int) throws -> SphereTexturePool {
        SphereTexturePool(device: try SphereTestSupport.device(), slotCount: capacity)
    }
}
