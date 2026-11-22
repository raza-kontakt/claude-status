import Foundation

public struct SessionRecord: Equatable {
    public var state: SessionState
    public var updated: Date
    /// Running background agents (subagents): agent id -> last time we heard from it.
    public var agents: [String: Date]
    public init(state: SessionState, updated: Date, agents: [String: Date] = [:]) {
        self.state = state
        self.updated = updated
        self.agents = agents
    }
}

public struct SessionTracker {
    /// A "working" session with no events for this long no longer holds the light red.
    public static let staleInterval: TimeInterval = 600
    /// A background agent we haven't heard from for this long is assumed gone (e.g. its stop event was lost).
    public static let agentStaleInterval: TimeInterval = 600
    public private(set) var sessions: [String: SessionRecord]

    public init(sessions: [String: SessionRecord] = [:]) {
        self.sessions = sessions
    }

    public mutating func apply(_ signal: Signal, at now: Date = Date()) {
        let id = signal.sessionID
        switch signal.kind {
        case .ended:
            sessions[id] = nil

        case .agentStarted:
            guard let agent = signal.agentID else { return }
            var rec = sessions[id] ?? SessionRecord(state: .idle, updated: now)
            rec.agents[agent] = now
            sessions[id] = rec

        case .agentStopped:
            guard let agent = signal.agentID, var rec = sessions[id] else { return }
            rec.agents[agent] = nil
            sessions[id] = rec

        case .working, .idle:
            if let agent = signal.agentID {
                // Fired from inside a subagent: it says the agent is alive, not that the main Claude is busy.
                guard var rec = sessions[id] else { return }
                if rec.agents[agent] != nil { rec.agents[agent] = now }
                if rec.state == .working { rec.updated = now }  // a foreground subagent keeps the main turn alive
                sessions[id] = rec
                return
            }
            var rec = sessions[id] ?? SessionRecord(state: .idle, updated: now)
            rec.state = signal.kind == .working ? .working : .idle
            rec.updated = now
            sessions[id] = rec
        }

        // Forget agents that went silent so a lost stop event can't leave the light yellow forever.
        if var rec = sessions[id] {
            rec.agents = rec.agents.filter { now.timeIntervalSince($0.value) < Self.agentStaleInterval }
            sessions[id] = rec
        }
    }

    public func light(at now: Date = Date()) -> Light {
        let busy = sessions.values.contains {
            $0.state == .working && now.timeIntervalSince($0.updated) < Self.staleInterval
        }
        if busy { return .red }
        let agentRunning = sessions.values.contains { rec in
            rec.agents.values.contains { now.timeIntervalSince($0) < Self.agentStaleInterval }
        }
        return agentRunning ? .yellow : .green
    }
}
