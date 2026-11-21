import Foundation

public struct SessionRecord: Equatable {
    public var state: SessionState
    public var updated: Date
    public init(state: SessionState, updated: Date) {
        self.state = state
        self.updated = updated
    }
}

public struct SessionTracker {
    public static let staleInterval: TimeInterval = 600
    public private(set) var sessions: [String: SessionRecord]

    public init(sessions: [String: SessionRecord] = [:]) {
        self.sessions = sessions
    }

    public mutating func apply(_ signal: Signal, at now: Date = Date()) {
        switch signal.kind {
        case .working: sessions[signal.sessionID] = SessionRecord(state: .working, updated: now)
        case .idle: sessions[signal.sessionID] = SessionRecord(state: .idle, updated: now)
        case .ended: sessions[signal.sessionID] = nil
        }
    }

    public func light(at now: Date = Date()) -> Light {
        let busy = sessions.values.contains {
            $0.state == .working && now.timeIntervalSince($0.updated) < Self.staleInterval
        }
        return busy ? .red : .green
    }
}
