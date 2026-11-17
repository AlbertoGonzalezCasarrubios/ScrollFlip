import AppKit
import SwiftUI

/// Detects the pointing-hand ("link") cursor shown by any app.
/// Only the cursor's shape is inspected, never the content under it.
enum CursorProbe {
    static func isPointingHand() -> Bool {
        guard let current = NSCursor.currentSystem else { return false }
        let hand = NSCursor.pointingHand
        if current.image.tiffRepresentation == hand.image.tiffRepresentation { return true }
        return sameShape(current, hand)
    }

    /// Fallback for scaled cursors (Accessibility → Pointer size): compare the
    /// hot spot relative to the image size, and the aspect ratio.
    private static func sameShape(_ a: NSCursor, _ b: NSCursor) -> Bool {
        let sa = a.image.size, sb = b.image.size
        guard sa.width > 0, sa.height > 0, sb.width > 0, sb.height > 0 else { return false }
        let ha = CGPoint(x: a.hotSpot.x / sa.width, y: a.hotSpot.y / sa.height)
        let hb = CGPoint(x: b.hotSpot.x / sb.width, y: b.hotSpot.y / sb.height)
        let aspect = abs(sa.width / sa.height - sb.width / sb.height)
        return abs(ha.x - hb.x) < 0.04 && abs(ha.y - hb.y) < 0.04 && aspect < 0.05
    }
}

/// Small floating anchor shown where autoscroll started (like Windows).
/// It ignores the mouse and never takes focus.
final class AnchorOverlay {
    private static let size: CGFloat = 38
    private var panel: NSPanel?

    /// `point` is in Quartz coordinates (origin at the top-left of the main display).
    func show(atQuartz point: CGPoint) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let mainHeight = NSScreen.screens.first?.frame.maxY ?? 0
        panel.setFrameOrigin(NSPoint(x: point.x - Self.size / 2,
                                     y: mainHeight - point.y - Self.size / 2))
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: Self.size, height: Self.size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: AnchorView())
        return panel
    }
}

private struct AnchorView: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.6))
            Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5)
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 38, height: 38)
    }
}
