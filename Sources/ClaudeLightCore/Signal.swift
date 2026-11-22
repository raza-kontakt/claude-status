import Foundation

public enum SessionState: String, Codable, Equatable {
    case working, idle
}

public enum Light: Equatable {
    /// Claude is working.
    case red
    /// Claude is free, but a background agent (subagent) is still running.
    case yellow
    /// Nothing is running.
    case green
}

public struct Signal: Equatable {
    public enum Kind: Equatable { case working, idle, ended, agentStarted, agentStopped }
    public let kind: Kind
    public let sessionID: String
    /// Set for SubagentStart/SubagentStop, and for any hook event that fired from inside a subagent.
    public let agentID: String?

    public init(kind: Kind, sessionID: String, agentID: String? = nil) {
        self.kind = kind
        self.sessionID = sessionID
        self.agentID = agentID
    }

    public static func kind(forEvent event: String) -> Kind? {
        switch event {
        case "UserPromptSubmit", "PreToolUse", "PostToolUse": return .working
        case "Stop", "Notification": return .idle  // Notification = Claude is waiting for the user
        case "SubagentStart": return .agentStarted
        case "SubagentStop": return .agentStopped
        case "SessionEnd": return .ended
        default: return nil
        }
    }

    /// Parses Claude hook JSON; `fallbackEvent` is used when the JSON has no event name.
    public static func parse(json: Data, fallbackEvent: String? = nil) -> Signal? {
        guard let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { return nil }
        let event = (obj["hook_event_name"] as? String) ?? fallbackEvent
        guard let event, let kind = kind(forEvent: event) else { return nil }
        let id = (obj["session_id"] as? String) ?? "default"
        guard Signal.isSafeID(id) else { return nil }
        var agent = obj["agent_id"] as? String
        if let a = agent, a.isEmpty || a.count > 128 { agent = nil }
        if (kind == .agentStarted || kind == .agentStopped) && agent == nil { return nil }
        return Signal(kind: kind, sessionID: id, agentID: agent)
    }

    /// Session ids become file names; reject anything that could escape the directory.
    public static func isSafeID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 128 && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}
