import AppKit
func sample(_ path: String) -> (r: NSColor, g: NSColor) {
    let rep = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: path)))!
    let w = rep.pixelsWide, h = rep.pixelsHigh
    // lamps are centred horizontally; red upper half, green lower half
    let red = rep.colorAt(x: w/2, y: Int(Double(h) * 0.30))!.usingColorSpace(.sRGB)!
    let green = rep.colorAt(x: w/2, y: Int(Double(h) * 0.70))!.usingColorSpace(.sRGB)!
    print((path as NSString).lastPathComponent, "size \(w)x\(h)", String(format: "upper=(%.2f,%.2f,%.2f) lower=(%.2f,%.2f,%.2f)", red.redComponent, red.greenComponent, red.blueComponent, green.redComponent, green.greenComponent, green.blueComponent))
    return (red, green)
}
let dir = CommandLine.arguments[1]
let r = sample(dir + "/red.png"), g = sample(dir + "/green.png")
func lit(_ c: NSColor, _ hue: String) -> Bool { hue == "red" ? (c.redComponent > 0.9 && c.greenComponent < 0.6) : (c.greenComponent > 0.85 && c.redComponent < 0.6) }
func dim(_ c: NSColor) -> Bool { c.redComponent < 0.45 && c.greenComponent < 0.45 && c.blueComponent < 0.45 }
let ok = lit(r.r, "red") && dim(r.g) && lit(g.g, "green") && dim(g.r)
print(ok ? "PASS: lit lamp is saturated, other lamp dim, in both states" : "FAIL")
exit(ok ? 0 : 1)
