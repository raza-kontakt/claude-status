import Foundation

public let pollInterval: TimeInterval = 0.25  // UI refresh; must stay well under the 1 s spec target

public struct StateStore {
    public let directory: URL

    public static func defaultDirectory(env: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let p = env["CLAUDE_LIGHT_DIR"], !p.isEmpty { return URL(fileURLWithPath: p, isDirectory: true) }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude-light/sessions", isDirectory: true)
    }

    public init(directory: URL = StateStore.defaultDirectory()) {
        self.directory = directory
    }

    private struct File: Codable { var state: SessionState; var updated: Double }

    private func url(_ id: String) -> URL { directory.appendingPathComponent("\(id).json") }

    public func write(_ signal: Signal, at now: Date = Date()) throws {
        guard Signal.isSafeID(signal.sessionID) else { return }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        if signal.kind == .ended {
            try? fm.removeItem(at: url(signal.sessionID))
            return
        }
        let file = File(state: signal.kind == .working ? .working : .idle, updated: now.timeIntervalSince1970)
        let data = try JSONEncoder().encode(file)
        // Atomic: write temp in same dir, then rename over target.
        let tmp = directory.appendingPathComponent(".\(signal.sessionID).\(UUID().uuidString).tmp")
        try data.write(to: tmp)
        _ = try fm.replaceItemAt(url(signal.sessionID), withItemAt: tmp)
    }

    /// Reads all session files; ignores malformed ones; prunes idle files older than a day.
    public func load(now: Date = Date()) -> SessionTracker {
        var out: [String: SessionRecord] = [:]
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return SessionTracker()
        }
        for item in items where item.pathExtension == "json" && !item.lastPathComponent.hasPrefix(".") {
            guard let data = try? Data(contentsOf: item),
                  let f = try? JSONDecoder().decode(File.self, from: data) else { continue }
            let updated = Date(timeIntervalSince1970: f.updated)
            if now.timeIntervalSince(updated) > 86_400 {
                try? fm.removeItem(at: item)
                continue
            }
            out[item.deletingPathExtension().lastPathComponent] = SessionRecord(state: f.state, updated: updated)
        }
        return SessionTracker(sessions: out)
    }
}
