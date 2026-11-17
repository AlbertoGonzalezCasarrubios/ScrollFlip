import CoreGraphics
import Foundation

/// Marks events ScrollFlip posts itself (autoscroll ticks, replayed middle
/// clicks) so none of its own event taps processes them again.
enum SyntheticEvent {
    static let marker: Int64 = 0x5343_524C   // "SCRL"

    static func isOurs(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }
}

enum AutoScrollMode: String, CaseIterable, Identifiable {
    /// Windows-style: click the wheel, move the mouse, click again to stop.
    /// A wheel click over a link (pointing-hand cursor) is passed through.
    case clickAndMove
    /// Hold the wheel and drag; release to stop. A plain wheel click is replayed.
    case holdAndDrag

    var id: String { rawValue }
}

/// Windows-style autoscroll on the middle button.
///
/// The state machine is pure: the pointer position, cursor shape, overlay and
/// event posting are injected closures, so tests can drive it step by step.
final class AutoScroller {
    enum State: Equatable {
        case idle
        /// Middle click over a link: let the down and its up through.
        case passingThrough
        /// Hold-and-drag mode: button down, not yet dragged far enough.
        case pending(anchor: CGPoint)
        /// Scrolling. `toggled` = click-and-move after release (stops on next click).
        case active(anchor: CGPoint, toggled: Bool, moved: Bool)
        /// Stopped by a click: swallow that button's up too.
        case swallowingUp
    }

    static let middleButton: Int64 = 2
    static let dragThreshold: CGFloat = 6
    static let deadZone: Double = 10
    static let maxSpeed: Double = 6000          // pixels per second
    static let tickInterval: TimeInterval = 1.0 / 60

    var mode: AutoScrollMode = .clickAndMove
    private(set) var state: State = .idle

    // Injected dependencies (real implementations by default).
    var cursorIsPointingHand: () -> Bool = { false }
    var pointerLocation: () -> CGPoint = { CGEvent(source: nil)?.location ?? .zero }
    var postScroll: (_ dx: Int32, _ dy: Int32, _ at: CGPoint) -> Void = AutoScroller.postScrollEvent
    var replayClick: (CGPoint) -> Void = AutoScroller.postMiddleClick
    var onStart: (CGPoint) -> Void = { _ in }
    var onStop: () -> Void = {}
    /// Tests turn this off and call tick(dt:) themselves.
    var usesTimer = true

    private var timer: Timer?
    private var remainder = (x: 0.0, y: 0.0)
    private var buttonTap: CFMachPort?
    private var buttonSource: CFRunLoopSource?
    private var exitTap: CFMachPort?
    private var exitSource: CFRunLoopSource?

    var isRunning: Bool { buttonTap != nil }
    var isScrolling: Bool { if case .active = state { return true } else { return false } }

    // MARK: State machine (returns true = swallow the event)

    func middleDown(at point: CGPoint) -> Bool {
        switch state {
        case .active(_, toggled: true, _):
            stop(swallowUp: true)
            return true
        case .idle, .passingThrough, .swallowingUp:
            break
        case .pending, .active:
            return true
        }

        switch mode {
        case .clickAndMove:
            if cursorIsPointingHand() {
                state = .passingThrough
                return false
            }
            start(anchor: point)
            return true
        case .holdAndDrag:
            state = .pending(anchor: point)
            return true
        }
    }

    func middleDragged(to point: CGPoint) -> Bool {
        switch state {
        case .pending(let anchor):
            if distance(point, anchor) > Self.dragThreshold { start(anchor: anchor, moved: true) }
            return true
        case .active(let anchor, let toggled, let moved):
            if !moved && distance(point, anchor) > Self.dragThreshold {
                state = .active(anchor: anchor, toggled: toggled, moved: true)
            }
            return true
        case .idle, .passingThrough, .swallowingUp:
            return false
        }
    }

    func middleUp(at point: CGPoint) -> Bool {
        switch state {
        case .idle:
            return false
        case .passingThrough:
            state = .idle
            return false
        case .swallowingUp:
            state = .idle
            setExitTap(enabled: false)
            return true
        case .pending(let anchor):
            state = .idle
            replayClick(anchor)               // it was just a click: give it back
            return true
        case .active(let anchor, toggled: false, moved: false) where mode == .clickAndMove:
            state = .active(anchor: anchor, toggled: true, moved: false)
            setExitTap(enabled: true)          // any click will now stop it
            return true
        case .active:
            stop(swallowUp: false)
            return true
        }
    }

    /// Left or right button pressed while toggled autoscroll is running.
    func otherButtonDown() -> Bool {
        guard case .active(_, toggled: true, _) = state else { return false }
        stop(swallowUp: true)
        return true
    }

    /// Left or right button released. Swallowed if its down stopped autoscroll.
    func otherButtonUp() -> Bool {
        guard state == .swallowingUp else { return false }
        state = .idle
        setExitTap(enabled: false)
        return true
    }

    /// Stops immediately (e.g. the user switched apps).
    func cancel() {
        if isScrolling || state != .idle { stop(swallowUp: false) }
    }

    // MARK: Scrolling

    /// Pixels per second for a pointer offset (in points) along one axis.
    static func velocity(offset: Double) -> Double {
        let distance = abs(offset) - deadZone
        guard distance > 0 else { return 0 }
        let speed = min(maxSpeed, 1.8 * pow(distance, 1.4))
        return offset > 0 ? speed : -speed
    }

    /// One animation step. Pointer below/right of the anchor scrolls the page
    /// down/right, like Windows, regardless of the "natural scrolling" setting
    /// (synthetic events are not affected by it).
    func tick(dt: Double) {
        guard case .active(let anchor, _, _) = state else { return }
        let pointer = pointerLocation()
        // Quartz coordinates: y grows downwards. Negative wheel delta = scroll down / right.
        remainder.x -= Self.velocity(offset: Double(pointer.x - anchor.x)) * dt
        remainder.y -= Self.velocity(offset: Double(pointer.y - anchor.y)) * dt
        let dx = remainder.x.rounded(.towardZero)
        let dy = remainder.y.rounded(.towardZero)
        remainder.x -= dx
        remainder.y -= dy
        if dx != 0 || dy != 0 {
            // Post at the CURRENT pointer position. Using the anchor here would
            // make macOS warp the cursor back to it on every tick.
            postScroll(Int32(dx), Int32(dy), pointer)
        }
    }

    private func start(anchor: CGPoint, moved: Bool = false) {
        state = .active(anchor: anchor, toggled: false, moved: moved)
        remainder = (0, 0)
        onStart(anchor)
        guard usesTimer else { return }
        timer?.invalidate()
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            self?.tick(dt: Self.tickInterval)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop(swallowUp: Bool) {
        let wasScrolling = isScrolling
        timer?.invalidate()
        timer = nil
        state = swallowUp ? .swallowingUp : .idle
        if !swallowUp { setExitTap(enabled: false) }
        if wasScrolling { onStop() }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: Posting events

    /// Posted at the session level: HID-level events with a location move the
    /// real cursor, which would fight the user's hand.
    static func postScrollEvent(dx: Int32, dy: Int32, at location: CGPoint) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                  wheel1: dy, wheel2: dx, wheel3: 0) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
        event.location = location
        event.post(tap: .cgSessionEventTap)
    }

    static func postMiddleClick(at location: CGPoint) {
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            guard let event = CGEvent(mouseEventSource: nil, mouseType: type,
                                      mouseCursorPosition: location, mouseButton: .center) else { continue }
            event.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
            event.post(tap: .cghidEventTap)
        }
    }

    // MARK: Event taps

    /// Middle-button tap. Exists only while the feature is on.
    @discardableResult
    func start() -> Bool {
        if buttonTap != nil { return true }
        let mask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
                 | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
                 | CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)
        guard let tap = makeTap(mask: mask, callback: middleButtonCallback) else { return false }
        buttonTap = tap.port
        buttonSource = tap.source
        return true
    }

    func stopTap() {
        cancel()
        setExitTap(enabled: false)
        remove(&buttonTap, &buttonSource)
    }

    func ensureRunning() -> Bool {
        if let buttonTap {
            if CGEvent.tapIsEnabled(tap: buttonTap) { return true }
            CGEvent.tapEnable(tap: buttonTap, enable: true)
            if CGEvent.tapIsEnabled(tap: buttonTap) { return true }
            remove(&self.buttonTap, &buttonSource)
        }
        return start()
    }

    /// Left/right click tap. Exists only while toggled autoscroll is running,
    /// so that any click can stop it (like Windows).
    private func setExitTap(enabled: Bool) {
        guard usesTimer else { return }    // tests: no real taps
        if enabled, exitTap == nil {
            let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
                     | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
                     | CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
                     | CGEventMask(1 << CGEventType.rightMouseUp.rawValue)
            if let tap = makeTap(mask: mask, callback: exitClickCallback) {
                exitTap = tap.port
                exitSource = tap.source
            }
        } else if !enabled {
            remove(&exitTap, &exitSource)
        }
    }

    fileprivate func reenable(_ port: CFMachPort?) {
        if let port { CGEvent.tapEnable(tap: port, enable: true) }
    }

    fileprivate var buttonPort: CFMachPort? { buttonTap }
    fileprivate var exitPort: CFMachPort? { exitTap }

    private func makeTap(mask: CGEventMask, callback: CGEventTapCallBack) -> (port: CFMachPort, source: CFRunLoopSource)? {
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                           options: .defaultTap, eventsOfInterest: mask,
                                           callback: callback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return nil }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return (port, source!)
    }

    private func remove(_ port: inout CFMachPort?, _ source: inout CFRunLoopSource?) {
        guard let p = port else { return }
        CGEvent.tapEnable(tap: p, enable: false)
        if let s = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        CFMachPortInvalidate(p)
        port = nil
        source = nil
    }
}

private func middleButtonCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                                  refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let scroller = Unmanaged<AutoScroller>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        scroller.reenable(scroller.buttonPort)
        return Unmanaged.passUnretained(event)
    }
    guard !SyntheticEvent.isOurs(event),
          event.getIntegerValueField(.mouseEventButtonNumber) == AutoScroller.middleButton
    else { return Unmanaged.passUnretained(event) }

    let swallow: Bool
    switch type {
    case .otherMouseDown: swallow = scroller.middleDown(at: event.location)
    case .otherMouseDragged: swallow = scroller.middleDragged(to: event.location)
    case .otherMouseUp: swallow = scroller.middleUp(at: event.location)
    default: swallow = false
    }
    return swallow ? nil : Unmanaged.passUnretained(event)
}

private func exitClickCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                               refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let scroller = Unmanaged<AutoScroller>.fromOpaque(refcon).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        scroller.reenable(scroller.exitPort)
    case .leftMouseDown, .rightMouseDown:
        if scroller.otherButtonDown() { return nil }
    case .leftMouseUp, .rightMouseUp:
        if scroller.otherButtonUp() { return nil }
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}
