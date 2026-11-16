// Draws the ScrollFlip app icon (1024×1024 PNG) with plain AppKit paths.
// Usage: swiftc scripts/make-icon.swift -o /tmp/make-icon && /tmp/make-icon out.png
// scripts/make-icon.sh turns the PNG into Resources/AppIcon.icns.
//
// Design: near-black tile, a fine silver mouse outline, and an electric-blue
// scroll wheel with an up chevron (silver) and a down chevron (blue).
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

let silver = color(0xDCE3EE)
let blueLight = color(0x6AA8FF)
let blueDeep = color(0x2563EB)

/// Rounded chevron centred on `center`, pointing up or down.
func chevron(center: NSPoint, up: Bool, width: CGFloat, height: CGFloat, stroke: NSColor) {
    let dy = up ? height / 2 : -height / 2
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x - width / 2, y: center.y - dy))
    path.line(to: NSPoint(x: center.x, y: center.y + dy))
    path.line(to: NSPoint(x: center.x + width / 2, y: center.y - dy))
    path.lineWidth = 26
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    stroke.setStroke()
    path.stroke()
}

func withShadow(_ shadowColor: NSColor, blur: CGFloat, offset: NSSize = .zero, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = shadowColor
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = offset
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Tile: macOS icon grid (824 px rounded square in a 1024 canvas).
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
withShadow(color(0x000000, 0.35), blur: 30, offset: NSSize(width: 0, height: -12)) {
    color(0x0B0D12).setFill()
    tilePath.fill()
}
NSGradient(starting: color(0x232733), ending: color(0x07080B))!.draw(in: tilePath, angle: -90)

// Soft blue glow behind the mouse.
NSGraphicsContext.saveGraphicsState()
tilePath.addClip()
NSGradient(colors: [blueDeep.withAlphaComponent(0.38), blueDeep.withAlphaComponent(0)])!
    .draw(fromCenter: NSPoint(x: 512, y: 520), radius: 0,
          toCenter: NSPoint(x: 512, y: 520), radius: 360, options: [])
NSGraphicsContext.restoreGraphicsState()

// Fine highlight along the tile edge.
let rim = NSBezierPath(roundedRect: tile.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
rim.lineWidth = 3
color(0xFFFFFF, 0.08).setStroke()
rim.stroke()

// Mouse: dark body with a silver outline.
let body = NSRect(x: 362, y: 292, width: 300, height: 456)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 150, yRadius: 150)
NSGradient(starting: color(0x1B1F29), ending: color(0x0E1016))!.draw(in: bodyPath, angle: -90)
bodyPath.lineWidth = 16
silver.setStroke()
bodyPath.stroke()

// Button split line.
let split = NSBezierPath()
split.move(to: NSPoint(x: body.midX, y: body.maxY - 8))
split.line(to: NSPoint(x: body.midX, y: body.maxY - 176))
split.lineWidth = 8
split.lineCapStyle = .round
silver.withAlphaComponent(0.45).setStroke()
split.stroke()

// Scroll wheel: glowing electric-blue capsule.
let wheel = NSRect(x: body.midX - 24, y: body.maxY - 196, width: 48, height: 116)
let wheelPath = NSBezierPath(roundedRect: wheel, xRadius: 24, yRadius: 24)
withShadow(blueLight.withAlphaComponent(0.9), blur: 36) {
    blueDeep.setFill()
    wheelPath.fill()
}
NSGradient(starting: blueLight, ending: blueDeep)!.draw(in: wheelPath, angle: -90)

// Chevrons above and below the mouse: scroll up / down, one of them flipped to blue.
chevron(center: NSPoint(x: 512, y: 832), up: true, width: 120, height: 52, stroke: silver)
withShadow(blueLight.withAlphaComponent(0.7), blur: 24) {
    chevron(center: NSPoint(x: 512, y: 206), up: false, width: 120, height: 52, stroke: blueLight)
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("✔ \(output)")
