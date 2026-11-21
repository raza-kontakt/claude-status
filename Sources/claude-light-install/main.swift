import Foundation
import ClaudeLightCore

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data((msg + "\n").utf8))
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first, ["install", "uninstall"].contains(command) else {
    fail("usage: claude-light-install install|uninstall [--settings PATH] [--hook PATH]")
}
args.removeFirst()

var settings = SettingsInstaller.defaultSettingsURL
let selfURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
var hook = selfURL.deletingLastPathComponent().appendingPathComponent("claude-light-hook").path

var i = 0
while i < args.count {
    guard i + 1 < args.count else { fail("missing value for \(args[i])") }
    switch args[i] {
    case "--settings": settings = URL(fileURLWithPath: args[i + 1])
    case "--hook": hook = args[i + 1]
    default: fail("unknown option \(args[i])")
    }
    i += 2
}

let installer = SettingsInstaller(settingsURL: settings, hookPath: hook)
do {
    if command == "install" {
        try installer.install()
        print("Installed Claude Light hooks into \(settings.path)")
    } else {
        try installer.uninstall()
        print("Removed Claude Light hooks from \(settings.path)")
    }
} catch {
    fail("error: \(error)")
}
