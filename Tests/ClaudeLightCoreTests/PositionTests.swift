import XCTest
@testable import ClaudeLightCore

final class PositionTests: XCTestCase {
    func store() -> PositionStore {
        let d = UserDefaults(suiteName: "cl-test-\(UUID().uuidString)")!
        return PositionStore(defaults: d)
    }
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testRoundTrip() {
        let s = store()
        XCTAssertNil(s.restore(visibleFrames: [screen]))
        s.save(CGPoint(x: 100, y: 200))
        XCTAssertEqual(s.restore(visibleFrames: [screen]), CGPoint(x: 100, y: 200))
    }

    func testOffscreenPositionRejected() {
        let s = store()
        s.save(CGPoint(x: 5000, y: 5000))
        XCTAssertNil(s.restore(visibleFrames: [screen]))
    }

    func testPollIntervalMeetsSpec() { XCTAssertLessThan(pollInterval, 1.0) }
}
