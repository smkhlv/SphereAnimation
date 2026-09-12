import Metal
import Synchronization

/// A rendered sphere texture together with GPU readiness and ownership metadata.
///
/// Copies share one lease. Call ``release()`` after the last GPU consumer has
/// completed its work; the producer slot is returned exactly once.
public struct SphereRenderedFrame: Sendable {
    private let textureReference: MetalTextureReference
    private let eventReference: MetalSharedEventReference
    private let lease: SphereFrameLease

    public var texture: MTLTexture { textureReference.value }
    public var readinessEvent: MTLSharedEvent { eventReference.value }
    public let readinessValue: UInt64

    public init(
        texture: MTLTexture,
        readinessEvent: MTLSharedEvent,
        readinessValue: UInt64,
        onRelease: @escaping @Sendable () -> Void = {}
    ) {
        textureReference = MetalTextureReference(texture)
        eventReference = MetalSharedEventReference(readinessEvent)
        self.readinessValue = readinessValue
        lease = SphereFrameLease(onRelease)
    }

    /// Releases this frame's producer slot. Repeated calls and calls on copies
    /// are safe and invoke the release action only once.
    public func release() {
        lease.release()
    }
}

private final class SphereFrameLease: Sendable {
    private let action: Mutex<(@Sendable () -> Void)?>

    init(_ action: @escaping @Sendable () -> Void) {
        self.action = Mutex(action)
    }

    func release() {
        let callback = action.withLock { action in
            defer { action = nil }
            return action
        }
        callback?()
    }

    deinit {
        release()
    }
}

private struct MetalTextureReference: @unchecked Sendable {
    let value: MTLTexture
    init(_ value: MTLTexture) { self.value = value }
}

private struct MetalSharedEventReference: @unchecked Sendable {
    let value: MTLSharedEvent
    init(_ value: MTLSharedEvent) { self.value = value }
}
