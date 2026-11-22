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

    // MARK: background agents (yellow light)

    func sig(_ k: Signal.Kind, _ s: String = "a", agent: String? = nil) -> Signal { Signal(kind: k, sessionID: s, agentID: agent) }

    func testParseSubagentEvents() {
        func p(_ json: String) -> Signal? { Signal.parse(json: Data(json.utf8)) }
        let start = p("{\"session_id\":\"a\",\"hook_event_name\":\"SubagentStart\",\"agent_id\":\"x1\",\"agent_type\":\"Explore\"}")
        XCTAssertEqual(start, Signal(kind: .agentStarted, sessionID: "a", agentID: "x1"))
        let stop = p("{\"session_id\":\"a\",\"hook_event_name\":\"SubagentStop\",\"agent_id\":\"x1\"}")
        XCTAssertEqual(stop, Signal(kind: .agentStopped, sessionID: "a", agentID: "x1"))
        // start/stop without an agent id can't be tracked
        XCTAssertNil(p("{\"session_id\":\"a\",\"hook_event_name\":\"SubagentStart\"}"))
        // a tool call made from inside a subagent carries agent_id
        XCTAssertEqual(p("{\"session_id\":\"a\",\"hook_event_name\":\"PreToolUse\",\"agent_id\":\"x1\"}")?.agentID, "x1")
        XCTAssertNil(p("{\"session_id\":\"a\",\"hook_event_name\":\"PreToolUse\"}")?.agentID)
    }

    func testBackgroundAgentWhileClaudeIdleIsYellow() {
        var t = SessionTracker()
        let now = Date()
        t.apply(sig(.working), at: now)
        t.apply(sig(.agentStarted, agent: "x1"), at: now)
        XCTAssertEqual(t.light(at: now), .red)            // Claude busy + agent running
        t.apply(sig(.idle), at: now)
        XCTAssertEqual(t.light(at: now), .yellow)         // Claude free, agent still running
        t.apply(sig(.agentStopped, agent: "x1"), at: now)
        XCTAssertEqual(t.light(at: now), .green)          // neither
    }

    func testSubagentToolCallsDoNotTurnLightRed() {
        var t = SessionTracker()
        let now = Date()
        t.apply(sig(.agentStarted, agent: "x1"), at: now)
        t.apply(sig(.idle), at: now)
        // the background agent keeps calling tools while Claude itself is idle
        t.apply(sig(.working, agent: "x1"), at: now.addingTimeInterval(5))
        t.apply(sig(.working, agent: "x1"), at: now.addingTimeInterval(6))
        XCTAssertEqual(t.light(at: now.addingTimeInterval(6)), .yellow)
        // ...but a real prompt from the user does
        t.apply(sig(.working), at: now.addingTimeInterval(7))
        XCTAssertEqual(t.light(at: now.addingTimeInterval(7)), .red)
    }

    func testSubagentActivityKeepsAgentAliveAndLateEventsDoNotResurrectIt() {
        var t = SessionTracker()
        let now = Date()
        t.apply(sig(.agentStarted, agent: "x1"), at: now)
        t.apply(sig(.idle), at: now)
        // silent for 9 min, then activity refreshes it
        t.apply(sig(.working, agent: "x1"), at: now.addingTimeInterval(540))
        XCTAssertEqual(t.light(at: now.addingTimeInterval(1000)), .yellow)
        t.apply(sig(.agentStopped, agent: "x1"), at: now.addingTimeInterval(1001))
        // a straggling event after the stop must not bring the agent back
        t.apply(sig(.working, agent: "x1"), at: now.addingTimeInterval(1002))
        XCTAssertEqual(t.light(at: now.addingTimeInterval(1002)), .green)
    }

    func testLostStopEventDoesNotLeaveLightYellowForever() {
        var t = SessionTracker()
        let now = Date()
        t.apply(sig(.agentStarted, agent: "x1"), at: now)
        t.apply(sig(.idle), at: now)
        XCTAssertEqual(t.light(at: now.addingTimeInterval(599)), .yellow)
        XCTAssertEqual(t.light(at: now.addingTimeInterval(601)), .green)
    }

    func testMultipleAgentsAndSessions() {
        var t = SessionTracker()
        let now = Date()
        t.apply(sig(.idle, "a"), at: now)
        t.apply(sig(.agentStarted, "a", agent: "x1"), at: now)
        t.apply(sig(.agentStarted, "a", agent: "x2"), at: now)
        t.apply(sig(.agentStopped, "a", agent: "x1"), at: now)
        XCTAssertEqual(t.light(at: now), .yellow)         // x2 still running
        t.apply(sig(.working, "b"), at: now)
        XCTAssertEqual(t.light(at: now), .red)            // red beats yellow
        t.apply(sig(.ended, "a"), at: now)
        t.apply(sig(.idle, "b"), at: now)
        XCTAssertEqual(t.light(at: now), .green)          // ending the session drops its agents
    }

    func testStopWithoutStartIsHarmless() {
        var t = SessionTracker()
        t.apply(sig(.agentStopped, agent: "ghost"))
        XCTAssertTrue(t.sessions.isEmpty)
        XCTAssertEqual(t.light(), .green)
    }

    func testStoreTracksAgentsAcrossProcesses() throws {
        let dir = tmpDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = StateStore(directory: dir)
        try s.write(sig(.working))
        try s.write(sig(.agentStarted, agent: "x1"))
        XCTAssertEqual(s.load().light(), .red)
        try s.write(sig(.idle))
        XCTAssertEqual(s.load().light(), .yellow)
        try s.write(sig(.agentStopped, agent: "x1"))
        XCTAssertEqual(s.load().light(), .green)
        try s.write(sig(.agentStopped, "never-seen", agent: "x"))  // must not create a file
        XCTAssertEqual(s.load().sessions.count, 1)
    }

    func testStoreReadsFilesFromOlderVersion() throws {
        let dir = tmpDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let now = Date().timeIntervalSince1970
        try Data("{\"state\":\"working\",\"updated\":\(now)}".utf8).write(to: dir.appendingPathComponent("old.json"))
        let s = StateStore(directory: dir)
        XCTAssertEqual(s.load().light(), .red)
        try s.write(sig(.agentStarted, "old", agent: "x1"))  // upgrades the file in place
        XCTAssertEqual(s.load().light(), .red)
    }

    func testConcurrentHooksDoNotLoseAgents() throws {
        let dir = tmpDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = StateStore(directory: dir)
        try s.write(sig(.idle))
        DispatchQueue.concurrentPerform(iterations: 40) { i in
            try? s.write(self.sig(.agentStarted, agent: "agent-\(i)"))
        }
        XCTAssertEqual(s.load().sessions["a"]?.agents.count, 40)
    }
}
