import XCTest
@testable import ClaudeLightCore

final class InstallerTests: XCTestCase {
    var dir: URL!
    var file: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("cl-inst-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        file = dir.appendingPathComponent("settings.json")
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func installer() -> SettingsInstaller { SettingsInstaller(settingsURL: file, hookPath: "/opt/claude-light-hook") }
    func json() throws -> NSDictionary {
        try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! NSDictionary
    }

    let original = """
    {"model":"opus","hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"echo hi"}]}],
     "Custom":[{"hooks":[{"type":"command","command":"x"}]}]},"env":{"A":"1"}}
    """

    func testCreatesMissingFile() throws {
        try installer().install()
        let hooks = try json()["hooks"] as! [String: Any]
        XCTAssertEqual(Set(hooks.keys), Set(SettingsInstaller.events))
    }

    func testPreservesExistingAndRoundTrips() throws {
        try original.write(to: file, atomically: true, encoding: .utf8)
        let before = try json()
        try installer().install()
        let mid = try json()
        XCTAssertEqual(mid["model"] as? String, "opus")
        XCTAssertEqual((mid["hooks"] as! [String: Any])["Stop"].map { ($0 as! [Any]).count }, 2)
        try installer().uninstall()
        XCTAssertEqual(try json(), before)
    }

    func testIdempotent() throws {
        try original.write(to: file, atomically: true, encoding: .utf8)
        try installer().install()
        let once = try json()
        try installer().install()
        XCTAssertEqual(try json(), once)
    }

    func testInvalidJSONUntouched() throws {
        try "{not json".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try installer().install()) { XCTAssertEqual($0 as? InstallerError, .invalidJSON) }
        XCTAssertEqual(try String(contentsOf: file), "{not json")
    }

    func testUninstallWithoutFileIsNoop() throws {
        try installer().uninstall()
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testPathWithSpacesIsQuoted() throws {
        let i = SettingsInstaller(settingsURL: file, hookPath: "/My Apps/claude-light-hook")
        try i.install()
        let s = try String(contentsOf: file)
        XCTAssertTrue(s.contains("'/My Apps/claude-light-hook' Stop"))
    }
}
