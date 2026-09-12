import Metal
import Dispatch
import Synchronization
import Testing
@testable import SphereAnimation

@Test func texturePoolIsBoundedAndDuplicateReleaseReturnsOneSlot() throws {
    let pool = try SphereTexturePool.testPool(capacity: 3)
    let first = try #require(pool.tryAcquire(width: 32, height: 24))
    let second = try #require(pool.tryAcquire(width: 32, height: 24))
    let third = try #require(pool.tryAcquire(width: 32, height: 24))

    #expect(pool.tryAcquire(width: 32, height: 24) == nil)
    #expect([first, second, third].allSatisfy {
        $0.texture.pixelFormat == .bgra8Unorm &&
        $0.texture.usage.contains(.renderTarget) &&
        $0.texture.usage.contains(.shaderRead)
    })

    first.release()
    first.release()
    #expect(pool.availableCount == 1)
    #expect(try #require(pool.tryAcquire(width: 32, height: 24)).id == first.id)
}

@Test func resizeCreatesANewGenerationAndIgnoresOldReturns() throws {
    let pool = try SphereTexturePool.testPool(capacity: 3)
    let old = try #require(pool.tryAcquire(width: 16, height: 16))
    let resized = try #require(pool.tryAcquire(width: 40, height: 20))

    #expect(resized.texture.width == 40)
    #expect(resized.texture.height == 20)
    #expect(pool.availableCount == 2)

    old.release()
    #expect(pool.availableCount == 2)
    resized.release()
    #expect(pool.availableCount == 3)
}

@Test func texturePoolHasCheckedSendableContract() {
    func requireSendable<T: Sendable>(_: T.Type) {}
    requireSendable(SphereTexturePool.self)
}

@Test func concurrentAcquisitionsNeverDuplicateSlots() throws {
    let pool = try SphereTexturePool.testPool(capacity: 3)
    let acquired = Mutex<[SphereTexturePool.Lease]>([])

    DispatchQueue.concurrentPerform(iterations: 1_000) { _ in
        guard let lease = pool.tryAcquire(width: 12, height: 12) else { return }
        acquired.withLock { $0.append(lease) }
    }

    var leases = acquired.withLock { $0 }
    #expect((1...3).contains(leases.count))
    #expect(Set(leases.map(\.id)).count == leases.count)

    while leases.count < 3 {
        leases.append(try #require(pool.tryAcquire(width: 12, height: 12)))
    }
    #expect(Set(leases.map(\.id)).count == 3)
    #expect(pool.tryAcquire(width: 12, height: 12) == nil)

    leases.forEach { $0.release() }
    #expect(pool.availableCount == 3)
}
