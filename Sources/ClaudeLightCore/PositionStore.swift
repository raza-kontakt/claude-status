import Foundation
import CoreGraphics

/// Persists the widget's window origin. Rejects positions that are no longer on any screen.
public struct PositionStore {
    public let defaults: UserDefaults
    public let key: String

    public init(defaults: UserDefaults = .standard, key: String = "ClaudeLight.origin") {
        self.defaults = defaults
        self.key = key
    }

    public func save(_ origin: CGPoint) {
        defaults.set([Double(origin.x), Double(origin.y)], forKey: key)
    }

    /// Returns the saved origin only if it lies inside one of `visibleFrames`.
    public func restore(visibleFrames: [CGRect]) -> CGPoint? {
        guard let a = defaults.array(forKey: key) as? [Double], a.count == 2 else { return nil }
        let p = CGPoint(x: a[0], y: a[1])
        return visibleFrames.contains { $0.contains(p) } ? p : nil
    }
}
