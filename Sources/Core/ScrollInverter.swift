import CoreGraphics
import Foundation

/// Summary of one event for the "Try it" tab. Never stored anywhere.
struct ScrollSample {
    enum Axis { case vertical, horizontal }
    let isContinuous: Bool
    let axis: Axis
    let input: Double
    let output: Double

    var wasInverted: Bool { (input > 0) != (output > 0) }
    var wasModified: Bool { input != output }
}

/// Intercepts ONLY scroll-wheel events and reverses / rescales the ones that
/// come from a classic mouse wheel. Trackpad and Magic Mouse events
/// (continuous events) pass through untouched.
///
/// Nothing is stored, logged or sent: each event is modified in memory and
/// immediately handed back to the system.
final class ScrollInverter {
    var isEnabled = true
    var invertVertical = true
    var invertHorizontal = false
    /// Multiplier for mouse-wheel distance. 1 = system default.
    var speed: Double = 1

    /// Only set while the settings window is open; when nil no extra work is done.
    var observer: ((ScrollSample) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    /// Creates the event tap. Returns false if Accessibility permission is missing.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,          // .defaultTap = we are allowed to modify events
            eventsOfInterest: mask,
            callback: scrollCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

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
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.runLoopSource = nil
    }

    /// Health check, called periodically and after waking from sleep.
    /// Re-enables the tap if macOS turned it off, or recreates it if it is gone.
    /// Returns false if it cannot be recreated (Accessibility permission revoked).
    func ensureRunning() -> Bool {
        if let tap {
            if CGEvent.tapIsEnabled(tap: tap) { return true }
            CGEvent.tapEnable(tap: tap, enable: true)
            if CGEvent.tapIsEnabled(tap: tap) { return true }
            stop()
        }
        return start()
    }

    /// macOS disables the tap if the callback is too slow; turn it back on.
    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    /// Reverses / rescales the event in place if it comes from a mouse wheel.
    /// Internal (not private) so the tests can feed it synthetic events.
    func process(_ event: CGEvent) {
        // Trackpad and Magic Mouse produce "continuous" (pixel) events.
        // A classic mouse wheel produces discrete (line) events.
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0

        // Only read when the settings window is open.
        let before = observer != nil ? Self.dominantDelta(event) : nil

        if isEnabled && !isContinuous {
            let vertical = (invertVertical ? -1 : 1) * speed
            let horizontal = (invertHorizontal ? -1 : 1) * speed
            if vertical != 1 {
                scale(event, by: vertical,
                      delta: .scrollWheelEventDeltaAxis1,
                      fixed: .scrollWheelEventFixedPtDeltaAxis1,
                      point: .scrollWheelEventPointDeltaAxis1)
            }
            if horizontal != 1 {
                scale(event, by: horizontal,
                      delta: .scrollWheelEventDeltaAxis2,
                      fixed: .scrollWheelEventFixedPtDeltaAxis2,
                      point: .scrollWheelEventPointDeltaAxis2)
            }
        }

        if let observer, let before, before.value != 0 {
            let after = Self.dominantDelta(event)
            observer(ScrollSample(isContinuous: isContinuous, axis: before.axis,
                                  input: before.value, output: after.value))
        }
    }

    /// Axis with the most movement in this event, and its value.
    private static func dominantDelta(_ event: CGEvent) -> (axis: ScrollSample.Axis, value: Double) {
        let v = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let h = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        return abs(v) >= abs(h) ? (.vertical, v) : (.horizontal, h)
    }

    private func scale(_ event: CGEvent, by factor: Double,
                       delta: CGEventField, fixed: CGEventField, point: CGEventField) {
        // Read all three before writing: setting one may make the system recompute the others.
        let d = event.getIntegerValueField(delta)
        let f = event.getDoubleValueField(fixed)
        let p = event.getIntegerValueField(point)
        event.setIntegerValueField(delta, value: Self.scaled(d, factor))
        event.setDoubleValueField(fixed, value: f * factor)
        event.setIntegerValueField(point, value: Self.scaled(p, factor))
    }

    /// Scales an integer delta without ever turning a real movement into 0.
    static func scaled(_ value: Int64, _ factor: Double) -> Int64 {
        guard value != 0 else { return 0 }
        let result = (Double(value) * factor).rounded()
        if result == 0 { return (Double(value) * factor) > 0 ? 1 : -1 }
        return Int64(result)
    }
}

private func scrollCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let inverter = Unmanaged<ScrollInverter>.fromOpaque(refcon).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        inverter.reenable()
    case .scrollWheel:
        inverter.process(event)
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}
