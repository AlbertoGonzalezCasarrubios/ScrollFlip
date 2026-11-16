import CoreGraphics

/// The three delta fields of one axis, read from an event.
private struct Deltas: Equatable, CustomStringConvertible {
    let line: Int64
    let fixed: Double
    let point: Int64

    init(_ event: CGEvent, horizontal: Bool = false) {
        line = event.getIntegerValueField(horizontal ? .scrollWheelEventDeltaAxis2 : .scrollWheelEventDeltaAxis1)
        fixed = event.getDoubleValueField(horizontal ? .scrollWheelEventFixedPtDeltaAxis2 : .scrollWheelEventFixedPtDeltaAxis1)
        point = event.getIntegerValueField(horizontal ? .scrollWheelEventPointDeltaAxis2 : .scrollWheelEventPointDeltaAxis1)
    }

    var description: String { "(line: \(line), fixed: \(fixed), point: \(point))" }
}

/// Synthetic scroll event. `continuous: true` mimics a trackpad / Magic Mouse.
private func wheelEvent(vertical: Int32, horizontal: Int32 = 0, continuous: Bool = false) -> CGEvent {
    let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2,
                        wheel1: vertical, wheel2: horizontal, wheel3: 0)!
    event.setIntegerValueField(.scrollWheelEventIsContinuous, value: continuous ? 1 : 0)
    return event
}

private func expectScaled(_ after: Deltas, _ before: Deltas, by factor: Double,
                          file: StaticString = #fileID, line: UInt = #line) {
    expectEqual(after.line, ScrollInverter.scaled(before.line, factor), "line delta", file: file, line: line)
    expectEqual(after.fixed, before.fixed * factor, "fixed delta", file: file, line: line)
    expectEqual(after.point, ScrollInverter.scaled(before.point, factor), "point delta", file: file, line: line)
}

func scrollInverterTests() {
    test("synthetic events carry non-zero deltas (sanity check)") {
        let d = Deltas(wheelEvent(vertical: 3))
        expect(d.line != 0 && d.fixed != 0 && d.point != 0, "deltas were \(d)")
    }

    test("mouse wheel is reversed on every delta field") {
        let inverter = ScrollInverter()
        let event = wheelEvent(vertical: 3)
        let before = Deltas(event)
        inverter.process(event)
        expectScaled(Deltas(event), before, by: -1)
    }

    test("trackpad / Magic Mouse (continuous) events are untouched") {
        let inverter = ScrollInverter()
        inverter.speed = 3
        let event = wheelEvent(vertical: 3, continuous: true)
        let before = Deltas(event)
        inverter.process(event)
        expectEqual(Deltas(event), before)
    }

    test("disabled inverter leaves events untouched") {
        let inverter = ScrollInverter()
        inverter.isEnabled = false
        let event = wheelEvent(vertical: -2)
        let before = Deltas(event)
        inverter.process(event)
        expectEqual(Deltas(event), before)
    }

    test("no reversal at default speed leaves events untouched") {
        let inverter = ScrollInverter()
        inverter.invertVertical = false
        let event = wheelEvent(vertical: 2, horizontal: 1)
        let before = (Deltas(event), Deltas(event, horizontal: true))
        inverter.process(event)
        expectEqual(Deltas(event), before.0, "vertical")
        expectEqual(Deltas(event, horizontal: true), before.1, "horizontal")
    }

    test("horizontal axis is only reversed when enabled") {
        let inverter = ScrollInverter()
        let event = wheelEvent(vertical: 0, horizontal: 2)
        let before = Deltas(event, horizontal: true)
        inverter.process(event)
        expectEqual(Deltas(event, horizontal: true), before, "default: untouched")

        inverter.invertHorizontal = true
        inverter.process(event)
        expectScaled(Deltas(event, horizontal: true), before, by: -1)
    }

    test("speed multiplies the distance, with and without reversal") {
        let inverter = ScrollInverter()
        inverter.invertVertical = false
        inverter.speed = 2
        var event = wheelEvent(vertical: 2)
        var before = Deltas(event)
        inverter.process(event)
        expectScaled(Deltas(event), before, by: 2)

        inverter.invertVertical = true
        event = wheelEvent(vertical: 2)
        before = Deltas(event)
        inverter.process(event)
        expectScaled(Deltas(event), before, by: -2)
    }

    test("scaled() rounds but never turns a real movement into zero") {
        expectEqual(ScrollInverter.scaled(1, 0.5), 1)
        expectEqual(ScrollInverter.scaled(-1, 0.5), -1)
        expectEqual(ScrollInverter.scaled(1, -0.5), -1)
        expectEqual(ScrollInverter.scaled(0, 4), 0)
        expectEqual(ScrollInverter.scaled(3, 2), 6)
        expectEqual(ScrollInverter.scaled(3, 1.5), 5)   // 4.5 rounds away from zero
        expectEqual(ScrollInverter.scaled(-4, -0.75), 3)
    }

    test("observer reports reversed mouse and unchanged trackpad samples") {
        let inverter = ScrollInverter()
        var samples: [ScrollSample] = []
        inverter.observer = { samples.append($0) }

        inverter.process(wheelEvent(vertical: 2))
        inverter.process(wheelEvent(vertical: 2, continuous: true))

        expectEqual(samples.count, 2, "sample count")
        guard samples.count == 2 else { return }
        expect(!samples[0].isContinuous && samples[0].wasInverted, "mouse sample should be reversed")
        expect(samples[1].isContinuous && !samples[1].wasModified, "trackpad sample should be unchanged")
    }

    test("observer reports speed-only changes as modified, not reversed") {
        let inverter = ScrollInverter()
        inverter.invertVertical = false
        inverter.speed = 2
        var sample: ScrollSample?
        inverter.observer = { sample = $0 }
        inverter.process(wheelEvent(vertical: 1))
        expect(sample?.wasModified == true && sample?.wasInverted == false, "got \(String(describing: sample))")
    }

    test("observer ignores events without movement") {
        let inverter = ScrollInverter()
        var calls = 0
        inverter.observer = { _ in calls += 1 }
        inverter.process(wheelEvent(vertical: 0))
        expectEqual(calls, 0)
    }
}
