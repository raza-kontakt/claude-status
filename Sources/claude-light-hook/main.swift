import Foundation
import ClaudeLightCore

// Always exits 0 and stays silent: must never disturb Claude Code.
let input = FileHandle.standardInput.readDataToEndOfFile()
let fallback = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : nil
if let signal = Signal.parse(json: input, fallbackEvent: fallback) {
    try? StateStore().write(signal)
}
exit(0)
