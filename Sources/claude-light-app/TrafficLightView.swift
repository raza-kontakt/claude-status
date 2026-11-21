import SwiftUI
import ServiceManagement
import ClaudeLightCore

final class LightModel: ObservableObject {
    @Published var light: Light = .green
    private let store = StateStore()
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        let next = store.load().light()
        if next != light {
            light = next
            if ProcessInfo.processInfo.environment["CLAUDE_LIGHT_DEBUG"] != nil {
                FileHandle.standardError.write(Data("light -> \(next)\n".utf8))
            }
        }
    }
}

struct LampView: View {
    let color: Color
    let lit: Bool
    let label: String

    var body: some View {
        Circle()
            .fill(lit ? color : color.opacity(0.18))
            .overlay(Circle().strokeBorder(Color.black.opacity(0.5), lineWidth: 1.5))
            .overlay(
                Circle().fill(
                    RadialGradient(colors: [Color.white.opacity(lit ? 0.55 : 0.08), .clear],
                                   center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: 15)
                )
            )
            .shadow(color: lit ? color.opacity(0.9) : .clear, radius: lit ? 8 : 0)
            .frame(width: 30, height: 30)
            .accessibilityLabel(label)
            .accessibilityValue(lit ? "on" : "off")
    }
}

struct TrafficLightView: View {
    @ObservedObject var model: LightModel
    var interactive = true

    var body: some View {
        VStack(spacing: 8) {
            LampView(color: Color(red: 1, green: 0.15, blue: 0.12), lit: model.light == .red, label: "Claude is working")
            LampView(color: Color(red: 0.1, green: 0.9, blue: 0.3), lit: model.light == .green, label: "Claude is finished")
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.1)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(white: 0.3), lineWidth: 2))
        .padding(3)
    }
}

/// Start-at-login toggle, backed by the system's login items (macOS 13+).
@MainActor final class LoginItemController: NSObject, NSMenuItemValidation {
    static let shared = LoginItemController()
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @objc func toggle(_ sender: Any?) {
        do {
            if isEnabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
        } catch {
            FileHandle.standardError.write(Data("login item: \(error.localizedDescription)\n".utf8))
            let alert = NSAlert()
            alert.messageText = "Couldn't change Start at Login"
            alert.informativeText = "Move Claude Light to the Applications folder and try again.\n\n\(error.localizedDescription)"
            alert.runModal()
        }
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        item.state = isEnabled ? .on : .off
        return true
    }
}

/// The right-click menu: Start at Login toggle and Quit.
@MainActor func makeQuitMenu() -> NSMenu {
    let menu = NSMenu()
    let login = NSMenuItem(title: "Start at Login", action: #selector(LoginItemController.toggle(_:)), keyEquivalent: "")
    login.target = LoginItemController.shared
    menu.addItem(login)
    menu.addItem(.separator())
    let item = NSMenuItem(title: "Quit Claude Light", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    item.target = NSApp
    menu.addItem(item)
    return menu
}

/// Container that owns the right-click menu and handles dragging itself, so SwiftUI content
/// can't swallow mouse events. Drag the widget anywhere by pressing on it and moving.
final class RightClickContainer: NSView {
    private var grabOffset = NSPoint.zero  // cursor position relative to the window origin

    init(content: NSView) {
        super.init(frame: NSRect(origin: .zero, size: content.fittingSize))
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
        menu = makeQuitMenu()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(convert(point, to: superview)) ? self : nil }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func screenPoint(_ event: NSEvent) -> NSPoint { window!.convertPoint(toScreen: event.locationInWindow) }

    override func mouseDown(with event: NSEvent) {
        guard let w = window else { return }
        let p = screenPoint(event)
        grabOffset = NSPoint(x: p.x - w.frame.origin.x, y: p.y - w.frame.origin.y)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let w = window else { return }
        let p = screenPoint(event)
        w.setFrameOrigin(NSPoint(x: p.x - grabOffset.x, y: p.y - grabOffset.y))
    }
}
