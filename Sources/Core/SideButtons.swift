import CoreGraphics
import Foundation

enum NavigationDirection: Equatable {
    case back, forward
}

/// How Back/Forward is delivered to the frontmost app.
enum NavigationStrategy: Equatable {
    /// Post a synthetic "swipe between pages" gesture. Layout-independent;
    /// understood by Apple apps (Safari, Finder, Preview…), Firefox and a few others.
    case swipe
    /// Leave the original button event alone: Chrome, Edge, VS Code, Arc… already
    /// map mouse buttons 4/5 to Back/Forward themselves.
    case passThrough

    /// Same allow-list used by LinearMouse and Mac Mouse Fix.
    static func forApp(bundleID: String?) -> NavigationStrategy {
        guard let id = bundleID?.lowercased() else { return .passThrough }
        if id.hasPrefix("com.apple.") { return .swipe }
        let swipeApps = ["org.mozilla.firefox", "com.operasoftware.opera", "com.binarynights.forklift"]
        return swipeApps.contains(where: { id.hasPrefix($0) }) ? .swipe : .passThrough
    }
}

/// What to do with one mouse-button event.
enum ButtonDecision: Equatable {
    case passThrough
    case consume
    case navigate(NavigationDirection)   // also consumes the event
}

/// Synthetic "navigation swipe" gesture events (the same ones a two-finger
/// trackpad swipe produces). These CGEvent fields are undocumented; the values
/// match SensibleSideButtons, LinearMouse and Mac Mouse Fix.
enum SwipeGesture {
    static let gestureEventType: UInt32 = 29        // NSEvent.EventType.gesture
    static let hidTypeField: UInt32 = 110           // kCGEventGestureHIDType
    static let directionField: UInt32 = 115         // swipe direction
    static let phaseField: UInt32 = 132             // gesture phase
    static let navigationSwipeHIDType: Int64 = 16   // kIOHIDEventTypeNavigationSwipe
    static let phaseBegan: Int64 = 1
    static let phaseEnded: Int64 = 4
    static let directionLeft: Int64 = 0b0100        // "swipe left" = Back
    static let directionRight: Int64 = 0b1000       // "swipe right" = Forward

    static func field(_ raw: UInt32) -> CGEventField { CGEventField(rawValue: raw)! }

    /// One event of the gesture. The direction only goes on the final (ended) event.
    static func makeEvent(_ direction: NavigationDirection, ended: Bool) -> CGEvent? {
        guard let event = CGEvent(source: nil),
              let type = CGEventType(rawValue: gestureEventType) else { return nil }
        event.type = type
        event.flags = CGEventFlags(rawValue: 256)
        event.setIntegerValueField(field(hidTypeField), value: navigationSwipeHIDType)
        event.setIntegerValueField(field(phaseField), value: ended ? phaseEnded : phaseBegan)
        if ended {
            event.setIntegerValueField(field(directionField),
                                       value: direction == .back ? directionLeft : directionRight)
        }
        return event
    }

    static func post(_ direction: NavigationDirection) {
        makeEvent(direction, ended: false)?.post(tap: .cghidEventTap)
        makeEvent(direction, ended: true)?.post(tap: .cghidEventTap)
    }
}

/// Turns mouse buttons 4 and 5 into Back / Forward.
///
/// Privacy: its event tap only exists while the feature is enabled, and it
/// only listens to "other" mouse buttons (not left or right clicks). Every
/// button except 4 and 5 is passed through untouched.
final class SideButtonMapper {
    /// CGEvent button numbers are 0-based: 0 left, 1 right, 2 middle, 3 and 4 the side buttons.
    static let backButton: Int64 = 3
    static let forwardButton: Int64 = 4

    var swapButtons = false
    /// Injected so the decision logic can be tested without AppKit.
    var frontmostBundleID: () -> String? = { nil }
    /// Injected so tests can observe navigation without posting real events.
    var performNavigation: (NavigationDirection) -> Void = SwipeGesture.post

    private var consumedButtons = Set<Int64>()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    // MARK: Decision logic (pure, unit-tested)

    func decide(button: Int64, isDown: Bool, bundleID: String?) -> ButtonDecision {
        guard button == Self.backButton || button == Self.forwardButton else { return .passThrough }

        if !isDown {
            // Swallow the "up" only if we swallowed the matching "down".
            return consumedButtons.remove(button) != nil ? .consume : .passThrough
        }

        guard NavigationStrategy.forApp(bundleID: bundleID) == .swipe else { return .passThrough }

        consumedButtons.insert(button)
        let isBack = (button == Self.backButton) != swapButtons
        return .navigate(isBack ? .back : .forward)
    }

    /// Returns true if the event must be swallowed.
    func handle(button: Int64, isDown: Bool) -> Bool {
        switch decide(button: button, isDown: isDown, bundleID: frontmostBundleID()) {
        case .passThrough:
            return false
        case .consume:
            return true
        case .navigate(let direction):
            performNavigation(direction)
            return true
        }
    }

    // MARK: Event tap

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
                 | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: sideButtonCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        tap = newTap
        runLoopSource = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.runLoopSource = nil
        consumedButtons.removeAll()
    }

    /// Same health check as ScrollInverter.ensureRunning().
    func ensureRunning() -> Bool {
        if let tap {
            if CGEvent.tapIsEnabled(tap: tap) { return true }
            CGEvent.tapEnable(tap: tap, enable: true)
            if CGEvent.tapIsEnabled(tap: tap) { return true }
            stop()
        }
        return start()
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    // MARK: Testing without side buttons

    /// Posts a synthetic click of button 4 or 5 at the pointer, which goes
    /// through the real pipeline exactly like a physical side button.
    static func simulateClick(_ direction: NavigationDirection) {
        let button = direction == .back ? backButton : forwardButton
        let location = CGEvent(source: nil)?.location ?? .zero
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            let event = CGEvent(mouseEventSource: nil, mouseType: type,
                                mouseCursorPosition: location,
                                mouseButton: CGMouseButton(rawValue: UInt32(button))!)
            event?.setIntegerValueField(.mouseEventButtonNumber, value: button)
            event?.post(tap: .cghidEventTap)
        }
    }
}

private func sideButtonCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let mapper = Unmanaged<SideButtonMapper>.fromOpaque(refcon).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        mapper.reenable()
    case .otherMouseDown, .otherMouseUp:
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        if mapper.handle(button: button, isDown: type == .otherMouseDown) {
            return nil
        }
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}
