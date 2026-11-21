import XCTest
@testable import ClaudeLightCore

final class CoreTests: XCTestCase {
    func tmpDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("cl-\(UUID().uuidString)")
        return u
    }

    func testParseEvents() {
        func p(_ e: String, id: String = "a") -> Signal? {
            Signal.parse(json: Data("{\"session_id\":\"\(id)\",\"hook_event_name\":\"\(e)\"}".utf8))
        }
        XCTAssertEqual(p("UserPromptSubmit")?.kind, .working)
        XCTAssertEqual(p("PreToolUse")?.kind, .working)
        XCTAssertEqual(p("PostToolUse")?.kind, .working)
        XCTAssertEqual(p("Stop")?.kind, .idle)
        XCTAssertEqual(p("SessionEnd")?.kind, .ended)
        XCTAssertEqual(p("Notification")?.kind, .idle)
        XCTAssertNil(p("PreCompact"))
        XCTAssertNil(p("Stop", id: "../evil"))
    }

    func testParseMalformedAndFallback() {
        XCTAssertNil(Signal.parse(json: Data("garbage".utf8)))
        XCTAssertNil(Signal.parse(json: Data()))
        XCTAssertEqual(Signal.parse(json: Data("{\"session_id\":\"s\"}".utf8), fallbackEvent: "Stop")?.kind, .idle)
        XCTAssertEqual(Signal.parse(json: Data("{}".utf8), fallbackEvent: "Stop")?.sessionID, "default")
    }

    func testTrackerTransitions() {
        var t = SessionTracker()
        let now = Date()
        XCTAssertEqual(t.light(at: now), .green)
        t.apply(Signal(kind: .working, sessionID: "a"), at: now)
        XCTAssertEqual(t.light(at: now), .red)
        t.apply(Signal(kind: .working, sessionID: "a"), at: now)
        XCTAssertEqual(t.light(at: now), .red)
        t.apply(Signal(kind: .idle, sessionID: "a"), at: now)
        XCTAssertEqual(t.light(at: now), .green)
    }

    func testMultipleSessions() {
        var t = SessionTracker()
        let now = Date()
        t.apply(Signal(kind: .working, sessionID: "a"), at: now)
        t.apply(Signal(kind: .working, sessionID: "b"), at: now)
        t.apply(Signal(kind: .idle, sessionID: "a"), at: now)
        XCTAssertEqual(t.light(at: now), .red)
        t.apply(Signal(kind: .ended, sessionID: "b"), at: now)
        XCTAssertEqual(t.light(at: now), .green)
    }

    func testStaleWorkingReverts() {
        var t = SessionTracker()
        let now = Date()
        t.apply(Signal(kind: .working, sessionID: "a"), at: now)
        XCTAssertEqual(t.light(at: now.addingTimeInterval(599)), .red)
        XCTAssertEqual(t.light(at: now.addingTimeInterval(601)), .green)
    }

    func testStoreRoundTrip() throws {
        let dir = tmpDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = StateStore(directory: dir)
        XCTAssertEqual(s.load().light(), .green) // missing dir
        try s.write(Signal(kind: .working, sessionID: "a"))
        XCTAssertEqual(s.load().light(), .red)
        try s.write(Signal(kind: .idle, sessionID: "a"))
        XCTAssertEqual(s.load().light(), .green)
        try s.write(Signal(kind: .working, sessionID: "b"))
        try s.write(Signal(kind: .ended, sessionID: "b"))
        XCTAssertEqual(s.load().sessions.count, 1)
    }

    func testStoreIgnoresCorruptAndPrunesOld() throws {
        let dir = tmpDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = StateStore(directory: dir)
        try s.write(Signal(kind: .idle, sessionID: "ok"))
        try Data("{nope".utf8).write(to: dir.appendingPathComponent("bad.json"))
        XCTAssertEqual(s.load().sessions.count, 1)
        let future = Date().addingTimeInterval(2 * 86_400)
        XCTAssertEqual(s.load(now: future).sessions.count, 0)
    }
}
