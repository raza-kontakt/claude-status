import Foundation

public enum InstallerError: Error, Equatable, CustomStringConvertible {
    case invalidJSON
    case unexpectedStructure(String)
    public var description: String {
        switch self {
        case .invalidJSON: return "settings file is not valid JSON; refusing to modify it"
        case .unexpectedStructure(let s): return "unexpected settings structure: \(s)"
        }
    }
}

public struct SettingsInstaller {
    public static let events = ["UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop", "Notification", "SessionEnd"]
    public static let marker = "claude-light-hook"

    public let settingsURL: URL
    public let hookPath: String

    public init(settingsURL: URL, hookPath: String) {
        self.settingsURL = settingsURL
        self.hookPath = hookPath
    }

    public static var defaultSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    private func load() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        let data = try Data(contentsOf: settingsURL)
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) { return [:] }
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { throw InstallerError.invalidJSON }
        guard let dict = obj as? [String: Any] else { throw InstallerError.unexpectedStructure("top level is not an object") }
        return dict
    }

    private func save(_ dict: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: settingsURL, options: .atomic)
    }

    private func isOurs(_ group: Any) -> Bool {
        guard let g = group as? [String: Any], let hooks = g["hooks"] as? [[String: Any]] else { return false }
        return hooks.contains { ($0["command"] as? String)?.contains(Self.marker) == true }
    }

    private func quoted(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    public func install() throws {
        var root = try load()
        guard var hooks = (root["hooks"] ?? [String: Any]()) as? [String: Any] else {
            throw InstallerError.unexpectedStructure("\"hooks\" is not an object")
        }
        for event in Self.events {
            guard var groups = (hooks[event] ?? [Any]()) as? [Any] else {
                throw InstallerError.unexpectedStructure("hooks.\(event) is not an array")
            }
            if groups.contains(where: isOurs) { continue }
            groups.append([
                "matcher": "",
                "hooks": [["type": "command", "command": "\(quoted(hookPath)) \(event)"]],
            ] as [String: Any])
            hooks[event] = groups
        }
        root["hooks"] = hooks
        try save(root)
    }

    public func uninstall() throws {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }
        var root = try load()
        guard var hooks = root["hooks"] as? [String: Any] else { return }
        for (event, value) in hooks {
            guard let groups = value as? [Any] else { continue }
            let kept = groups.filter { !isOurs($0) }
            if kept.isEmpty { hooks[event] = nil } else { hooks[event] = kept }
        }
        if hooks.isEmpty { root["hooks"] = nil } else { root["hooks"] = hooks }
        try save(root)
    }
}
