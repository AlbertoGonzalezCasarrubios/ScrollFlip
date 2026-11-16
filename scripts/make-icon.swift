// Draws the ScrollFlip app icon (1024×1024 PNG) with plain AppKit paths.
// Usage: swiftc scripts/make-icon.swift -o /tmp/make-icon && /tmp/make-icon out.png
// scripts/make-icon.sh turns the PNG into Resources/AppIcon.icns.
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

/// Vertical arrow centred on `x`, pointing up or down.
func arrow(x: CGFloat, centerY: CGFloat, up: Bool, fill: NSColor) {
    let length: CGFloat = 330, shaft: CGFloat = 34, headWidth: CGFloat = 112, headHeight: CGFloat = 96
    let tip = up ? centerY + length / 2 : centerY - length / 2
    let tail = up ? centerY - length / 2 : centerY + length / 2
    let headBase = up ? tip - headHeight : tip + headHeight

    let path = NSBezierPath()
    path.move(to: NSPoint(x: x, y: tip))
    path.line(to: NSPoint(x: x + headWidth / 2, y: headBase))
    path.line(to: NSPoint(x: x + shaft / 2, y: headBase))
    path.line(to: NSPoint(x: x + shaft / 2, y: tail))
    path.line(to: NSPoint(x: x - shaft / 2, y: tail))
    path.line(to: NSPoint(x: x - shaft / 2, y: headBase))
    path.line(to: NSPoint(x: x - headWidth / 2, y: headBase))
    path.close()
    path.lineJoinStyle = .round
    fill.setFill()
    path.fill()
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Background: macOS icon grid (824 px rounded square inside a 1024 canvas) with a soft shadow.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = color(0x000000, 0.28)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.set()
color(0x3D44D8).setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: color(0x5E8DFF), ending: color(0x3A36C9))!.draw(in: tilePath, angle: -90)

// Mouse body.
let body = NSRect(x: 250, y: 262, width: 300, height: 500)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 150, yRadius: 150)
NSGraphicsContext.saveGraphicsState()
let bodyShadow = NSShadow()
bodyShadow.shadowColor = color(0x000000, 0.22)
bodyShadow.shadowOffset = NSSize(width: 0, height: -8)
bodyShadow.shadowBlurRadius = 20
bodyShadow.set()
color(0xFFFFFF).setFill()
bodyPath.fill()
NSGraphicsContext.restoreGraphicsState()

// Button split line.
let split = NSBezierPath()
split.move(to: NSPoint(x: body.midX, y: body.maxY))
split.line(to: NSPoint(x: body.midX, y: body.maxY - 190))
split.lineWidth = 8
color(0xC9CCE8).setStroke()
split.stroke()

// Scroll wheel (accent).
let wheel = NSRect(x: body.midX - 22, y: body.maxY - 175, width: 44, height: 104)
color(0xFFB21E).setFill()
NSBezierPath(roundedRect: wheel, xRadius: 22, yRadius: 22).fill()

// Arrows: one up, one down, so the icon reads as "flip the scroll direction".
arrow(x: 668, centerY: 512, up: true, fill: color(0xFFFFFF, 0.95))
arrow(x: 788, centerY: 512, up: false, fill: color(0xFFB21E))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("✔ \(output)")
