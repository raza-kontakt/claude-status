import AppKit
import SwiftUI
import ClaudeLightCore

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel!
    let model = LightModel()
    let positions = PositionStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingView(rootView: TrafficLightView(model: model))
        let size = host.fittingSize
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
        let container = RightClickContainer(content: host)
        panel.contentView = container
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovableByWindowBackground = false  // dragging is handled by RightClickContainer
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        let frames = NSScreen.screens.map { $0.visibleFrame }
        if let p = positions.restore(visibleFrames: frames) { panel.setFrameOrigin(p) } else { placeDefault() }

        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.positions.save(self.panel.frame.origin)
        }
        panel.orderFrontRegardless()
        if CommandLine.arguments.contains("--selftest-login") { MainActor.assumeIsolated { selfTestLogin(container) } }
        if CommandLine.arguments.contains("--selftest-quit") { selfTestQuit(container) }
        if CommandLine.arguments.contains("--selftest-drag") { selfTestDrag(container) }
    }

    /// Verification aid: simulate press-and-drag on the widget and check the window follows the cursor.
    func selfTestDrag(_ view: NSView) {
        func ev(_ type: NSEvent.EventType, screen p: NSPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: panel.convertPoint(fromScreen: p), modifierFlags: [], timestamp: 0,
                               windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        let start = panel.frame.origin
        let grab = NSPoint(x: start.x + 20, y: start.y + 30)
        view.mouseDown(with: ev(.leftMouseDown, screen: grab))
        for step in 1...5 { view.mouseDragged(with: ev(.leftMouseDragged, screen: NSPoint(x: grab.x - 20 * CGFloat(step), y: grab.y - 12 * CGFloat(step)))) }
        let moved = panel.frame.origin
        let ok = abs(moved.x - (start.x - 100)) < 0.5 && abs(moved.y - (start.y - 60)) < 0.5
        FileHandle.standardError.write(Data("selftest-drag: \(start) -> \(moved) \(ok ? "PASS" : "FAIL")\n".utf8))
        exit(ok ? 0 : 4)
    }

    /// Verification aid: invoke the "Start at Login" menu item and report the resulting login-item status.
    @MainActor func selfTestLogin(_ host: NSView) {
        guard let event = NSEvent.mouseEvent(with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
                                             windowNumber: host.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1),
              let menu = host.menu(for: event), let item = menu.items.first(where: { $0.title == "Start at Login" }) else {
            FileHandle.standardError.write(Data("selftest: no Start at Login item\n".utf8)); exit(2)
        }
        let before = LoginItemController.shared.isEnabled
        _ = menu.performActionForItem(at: menu.index(of: item))
        _ = LoginItemController.shared.validateMenuItem(item)
        print("login before=\(before) after=\(LoginItemController.shared.isEnabled) checkmark=\(item.state == .on)")
        exit(0)
    }

    /// Verification aid: obtain the right-click menu for the widget and activate its Quit item.
    func selfTestQuit(_ host: NSView) {
        guard let event = NSEvent.mouseEvent(with: .rightMouseDown, location: NSPoint(x: 10, y: 10), modifierFlags: [],
                                             timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                                             eventNumber: 0, clickCount: 1, pressure: 1),
              let menu = host.menu(for: event), let item = menu.items.first(where: { $0.title == "Quit Claude Light" }) else {
            FileHandle.standardError.write(Data("selftest: no Quit menu item\n".utf8)); exit(2)
        }
        FileHandle.standardError.write(Data("selftest: invoking '\(item.title)'\n".utf8))
        menu.performActionForItem(at: menu.index(of: item))
        // If terminate did not end the process shortly, report failure.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            FileHandle.standardError.write(Data("selftest: app still running after Quit\n".utf8)); exit(3)
        }
    }

    func placeDefault() {
        if let f = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.maxX - panel.frame.width - 24, y: f.maxY - panel.frame.height - 24))
        }
    }
}

// Offscreen snapshot mode for verification: claude-light-app --snapshot out.png red|yellow|green
@MainActor func snapshot(path: String, state: String) {
    let model = LightModel()
    model.light = state == "red" ? .red : (state == "yellow" ? .yellow : .green)
    // Optional env overrides for documentation shots; defaults match the pixel check (1x, white backdrop).
    let env = ProcessInfo.processInfo.environment
    let backdrop = env["CLAUDE_LIGHT_SNAPSHOT_TRANSPARENT"] != nil ? Color.clear : Color.white
    let renderer = ImageRenderer(content: TrafficLightView(model: model).background(backdrop))
    renderer.scale = CGFloat(Double(env["CLAUDE_LIGHT_SNAPSHOT_SCALE"] ?? "") ?? 1)
    guard let cg = renderer.cgImage else { FileHandle.standardError.write(Data("render failed\n".utf8)); exit(1) }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    exit(0)
}
if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--snapshot" {
    MainActor.assumeIsolated { snapshot(path: CommandLine.arguments[2], state: CommandLine.arguments[3]) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
