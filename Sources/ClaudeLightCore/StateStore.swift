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

    private struct File: Codable {
        var state: SessionState
        var updated: Double
        var agents: [String: Double]?  // absent in files written by older versions
    }

    private func url(_ id: String) -> URL { directory.appendingPathComponent("\(id).json") }

    private func read(_ url: URL) -> SessionRecord? {
        guard let data = try? Data(contentsOf: url), let f = try? JSONDecoder().decode(File.self, from: data) else { return nil }
        return SessionRecord(state: f.state, updated: Date(timeIntervalSince1970: f.updated),
                             agents: (f.agents ?? [:]).mapValues { Date(timeIntervalSince1970: $0) })
    }

    /// Applies one signal to that session's file. Hooks run concurrently (subagents fire in parallel),
    /// so the read-modify-write is serialised with a lock file.
    public func write(_ signal: Signal, at now: Date = Date()) throws {
        guard Signal.isSafeID(signal.sessionID) else { return }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let lockFD = open(directory.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o600)
        if lockFD >= 0 { flock(lockFD, LOCK_EX) }
        defer { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD) } }

        let id = signal.sessionID
        var tracker = SessionTracker(sessions: read(url(id)).map { [id: $0] } ?? [:])
        tracker.apply(signal, at: now)

        guard let rec = tracker.sessions[id] else {
            try? fm.removeItem(at: url(id))
            return
        }
        let file = File(state: rec.state, updated: rec.updated.timeIntervalSince1970,
                        agents: rec.agents.isEmpty ? nil : rec.agents.mapValues { $0.timeIntervalSince1970 })
        let data = try JSONEncoder().encode(file)
        // Atomic: write temp in same dir, then rename over target.
        let tmp = directory.appendingPathComponent(".\(id).\(UUID().uuidString).tmp")
        try data.write(to: tmp)
        _ = try fm.replaceItemAt(url(id), withItemAt: tmp)
    }

    /// Reads all session files; ignores malformed ones; prunes idle files older than a day.
    public func load(now: Date = Date()) -> SessionTracker {
        var out: [String: SessionRecord] = [:]
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return SessionTracker()
        }
        for item in items where item.pathExtension == "json" && !item.lastPathComponent.hasPrefix(".") {
            guard let rec = read(item) else { continue }
            if now.timeIntervalSince(rec.updated) > 86_400 {
                try? fm.removeItem(at: item)
                continue
            }
            out[item.deletingPathExtension().lastPathComponent] = rec
        }
        return SessionTracker(sessions: out)
    }
}
