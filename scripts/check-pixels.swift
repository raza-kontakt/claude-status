import AppKit

// Lamps are centred horizontally and stacked red (top), yellow (middle), green (bottom).
let lamps = ["red", "yellow", "green"]
let rows = [0.21, 0.50, 0.79]  // vertical centre of each lamp as a fraction of the image height

func sample(_ path: String) -> [NSColor] {
    let rep = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: path)))!
    let w = rep.pixelsWide, h = rep.pixelsHigh
    return rows.map { rep.colorAt(x: w / 2, y: Int(Double(h) * $0))!.usingColorSpace(.sRGB)! }
}
func lit(_ c: NSColor, _ hue: String) -> Bool {
    switch hue {
    case "red": return c.redComponent > 0.9 && c.greenComponent < 0.6
    case "yellow": return c.redComponent > 0.9 && c.greenComponent > 0.7 && c.blueComponent < 0.6
    default: return c.greenComponent > 0.85 && c.redComponent < 0.6
    }
}
func dim(_ c: NSColor) -> Bool { c.redComponent < 0.45 && c.greenComponent < 0.45 && c.blueComponent < 0.45 }

let dir = CommandLine.arguments[1]
var ok = true
for state in lamps {
    let colors = sample(dir + "/\(state).png")
    print(state + ".png", colors.map { String(format: "(%.2f,%.2f,%.2f)", $0.redComponent, $0.greenComponent, $0.blueComponent) }.joined(separator: " "))
    for (i, lamp) in lamps.enumerated() {
        let good = lamp == state ? lit(colors[i], lamp) : dim(colors[i])
        if !good { ok = false; print("  FAIL: \(lamp) lamp should be \(lamp == state ? "lit" : "dim") in the \(state) state") }
    }
}
print(ok ? "PASS: in each state the matching lamp is saturated and the other two are dim" : "FAIL")
exit(ok ? 0 : 1)
