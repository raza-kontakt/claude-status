// Renders the app icon (traffic light on a rounded square) to a PNG.
// Usage: swift scripts/make-icon.swift out.png
import AppKit

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
let s = CGFloat(size)

// Background tile (macOS icon grid: ~824pt tile centred in 1024)
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let bg = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor(white: 0.16, alpha: 1).setFill(); bg.fill()
ctx.restoreGState()
NSGradient(colors: [NSColor(white: 0.30, alpha: 1), NSColor(white: 0.10, alpha: 1)])!.draw(in: bg, angle: -90)

// Housing
let housing = NSBezierPath(roundedRect: NSRect(x: 372, y: 190, width: 280, height: 644), xRadius: 110, yRadius: 110)
NSColor(white: 0.07, alpha: 1).setFill(); housing.fill()
NSColor(white: 0.38, alpha: 1).setStroke(); housing.lineWidth = 10; housing.stroke()

func lamp(center: NSPoint, color: NSColor, lit: Bool) {
    let r: CGFloat = 84
    let rect = NSRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
    ctx.saveGState()
    if lit { ctx.setShadow(offset: .zero, blur: 60, color: color.withAlphaComponent(0.95).cgColor) }
    (lit ? color : color.withAlphaComponent(0.22)).setFill()
    NSBezierPath(ovalIn: rect).fill()
    ctx.restoreGState()
    NSColor.black.withAlphaComponent(0.55).setStroke()
    let ring = NSBezierPath(ovalIn: rect); ring.lineWidth = 8; ring.stroke()
    let hl = NSRect(x: center.x - r * 0.6, y: center.y + r * 0.1, width: r * 0.9, height: r * 0.7)
    NSGradient(colors: [NSColor.white.withAlphaComponent(lit ? 0.6 : 0.1), .clear])!
        .draw(in: NSBezierPath(ovalIn: hl), relativeCenterPosition: NSPoint(x: -0.3, y: 0.3))
}
lamp(center: NSPoint(x: s / 2, y: 700), color: NSColor(red: 1, green: 0.15, blue: 0.12, alpha: 1), lit: false)
lamp(center: NSPoint(x: s / 2, y: 512), color: NSColor(red: 1, green: 0.78, blue: 0.1, alpha: 1), lit: false)
lamp(center: NSPoint(x: s / 2, y: 324), color: NSColor(red: 0.1, green: 0.9, blue: 0.3, alpha: 1), lit: true)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
