import Metal
import Synchronization
import Testing
@testable import SphereAnimation

@Test func renderedFrameSharesAnExactlyOnceReleaseAcrossCopies() throws {
    let releaseCount = Mutex(0)

    let frame = try SphereRenderedFrame.testFrame {
        releaseCount.withLock { $0 += 1 }
    }
    let copy = frame

    #expect(frame.texture.width == 1)
    #expect(frame.readinessValue == 1)

    frame.release()
    copy.release()

    #expect(releaseCount.withLock { $0 } == 1)
}

@Test func renderedFrameHasCheckedSendableContract() {
    func requireSendable<T: Sendable>(_: T.Type) {}
    requireSendable(SphereRenderedFrame.self)
}
