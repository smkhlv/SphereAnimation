import Metal
import Synchronization

/// A bounded, generation-safe pool of renderable textures.
final class SphereTexturePool: Sendable {
    final class Lease: Sendable {
        private let textureReference: PoolTextureReference
        private let lifetime: SpherePoolLease

        var texture: MTLTexture { textureReference.value }
        let id: Int

        fileprivate init(slot: Slot, onRelease: @escaping @Sendable () -> Void) {
            textureReference = slot.texture
            id = slot.id
            lifetime = SpherePoolLease(onRelease)
        }

        func release() {
            lifetime.release()
        }
    }

    fileprivate struct Slot: Sendable {
        let id: Int
        let texture: PoolTextureReference
    }

    private struct Size: Equatable, Sendable {
        let width: Int
        let height: Int
    }

    private final class Generation: @unchecked Sendable {
        var id: UInt64
        let size: Size
        var slots: [Slot?]

        init(id: UInt64, size: Size, textures: [MTLTexture]) {
            self.id = id
            self.size = size
            slots = textures.enumerated().map {
                Slot(id: $0.offset, texture: PoolTextureReference($0.element))
            }
        }
    }

    private struct State {
        var nextGenerationID: UInt64 = 0
        var current: Generation?
    }

    private enum Acquisition {
        case acquired(Slot, generation: UInt64)
        case empty
        case resize
    }

    private enum Installation {
        case installed(Generation?)
        case alreadyCurrent
    }

    private let device: PoolDeviceReference
    private let slotCount: Int
    private let state = Mutex(State())

    init(device: MTLDevice, slotCount: Int = 3) {
        precondition(slotCount > 0)
        self.device = PoolDeviceReference(device)
        self.slotCount = slotCount
    }

    func tryAcquire(width: Int, height: Int) -> Lease? {
        guard width > 0, height > 0 else { return nil }
        let requestedSize = Size(width: width, height: height)

        guard let acquisition = acquireExisting(size: requestedSize) else {
            return nil
        }
        if case .resize = acquisition {
            // Texture allocation happens after the mutex has been released.
        } else {
            return makeLease(from: acquisition)
        }

        guard let replacement = makeGeneration(size: requestedSize) else { return nil }
        guard let installation = state.withLockIfAvailable({ state -> Installation in
            guard state.current?.size != requestedSize else { return .alreadyCurrent }
            state.nextGenerationID &+= 1
            replacement.id = state.nextGenerationID
            let retired = state.current
            state.current = replacement
            return .installed(retired)
        }) else {
            return nil
        }

        switch installation {
        case let .installed(retired):
            withExtendedLifetime(retired) {}
        case .alreadyCurrent:
            return makeLease(from: acquireExisting(size: requestedSize))
        }
        return makeLease(from: acquireExisting(size: requestedSize))
    }

    var availableCount: Int {
        state.withLock { state in
            state.current?.slots.reduce(into: 0) { count, slot in
                if slot != nil { count += 1 }
            } ?? 0
        }
    }

    private func acquireExisting(size: Size) -> Acquisition? {
        state.withLockIfAvailable { state in
            guard let generation = state.current else { return .resize }
            guard generation.size == size else { return .resize }
            guard let index = generation.slots.lastIndex(where: { $0 != nil }) else {
                return .empty
            }
            let slot = generation.slots[index]!
            generation.slots[index] = nil
            return .acquired(slot, generation: generation.id)
        }
    }

    private func makeLease(from acquisition: Acquisition?) -> Lease? {
        guard case let .acquired(slot, generation) = acquisition else { return nil }
        return Lease(slot: slot) { [weak self] in
            self?.returnSlot(slot, generation: generation)
        }
    }

    private func makeGeneration(size: Size) -> Generation? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: size.width,
            height: size.height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private

        var textures: [MTLTexture] = []
        textures.reserveCapacity(slotCount)
        for _ in 0..<slotCount {
            guard let texture = device.value.makeTexture(descriptor: descriptor) else { return nil }
            textures.append(texture)
        }
        return Generation(id: 0, size: size, textures: textures)
    }

    private func returnSlot(_ slot: Slot, generation: UInt64) {
        state.withLock { state in
            guard
                let current = state.current,
                current.id == generation,
                current.slots.indices.contains(slot.id),
                current.slots[slot.id] == nil
            else { return }
            current.slots[slot.id] = slot
        }
    }
}

private final class SpherePoolLease: Sendable {
    private let action: Mutex<(@Sendable () -> Void)?>

    init(_ action: @escaping @Sendable () -> Void) { self.action = Mutex(action) }

    func release() {
        let callback = action.withLock { action in
            defer { action = nil }
            return action
        }
        callback?()
    }

    deinit { release() }
}

private struct PoolTextureReference: @unchecked Sendable {
    let value: MTLTexture
    init(_ value: MTLTexture) { self.value = value }
}

private struct PoolDeviceReference: @unchecked Sendable {
    let value: MTLDevice
    init(_ value: MTLDevice) { self.value = value }
}
