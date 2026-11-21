import Foundation

public enum SessionState: String, Codable, Equatable {
    case working, idle
}

public enum Light: Equatable {
    case red, green
}

public struct Signal: Equatable {
    public enum Kind: Equatable { case working, idle, ended }
    public let kind: Kind
    public let sessionID: String

    public init(kind: Kind, sessionID: String) {
        self.kind = kind
        self.sessionID = sessionID
    }

    public static func kind(forEvent event: String) -> Kind? {
        switch event {
        case "UserPromptSubmit", "PreToolUse", "PostToolUse": return .working
        case "Stop", "Notification": return .idle  // Notification = Claude is waiting for the user
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
        return Signal(kind: kind, sessionID: id)
    }

    /// Session ids become file names; reject anything that could escape the directory.
    public static func isSafeID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 128 && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}
