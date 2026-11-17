import CoreGraphics

/// AutoScroller with every side effect captured instead of performed.
private final class Harness {
    let scroller = AutoScroller()
    var pointer = CGPoint(x: 500, y: 500)
    var cursorIsHand = false
    var scrolls: [(dx: Int32, dy: Int32)] = []
    var scrollLocations: [CGPoint] = []
    var replays: [CGPoint] = []
    var starts: [CGPoint] = []
    var stops = 0

    init(mode: AutoScrollMode) {
        scroller.mode = mode
        scroller.usesTimer = false
        scroller.pointerLocation = { [unowned self] in self.pointer }
        scroller.cursorIsPointingHand = { [unowned self] in self.cursorIsHand }
        scroller.postScroll = { [unowned self] dx, dy, at in
            self.scrolls.append((dx, dy))
            self.scrollLocations.append(at)
        }
        scroller.replayClick = { [unowned self] in self.replays.append($0) }
        scroller.onStart = { [unowned self] in self.starts.append($0) }
        scroller.onStop = { [unowned self] in self.stops += 1 }
    }

    var totalScroll: (dx: Int, dy: Int) {
        scrolls.reduce((0, 0)) { ($0.0 + Int($1.dx), $0.1 + Int($1.dy)) }
    }

    func ticks(_ n: Int) {
        for _ in 0..<n { scroller.tick(dt: AutoScroller.tickInterval) }
    }
}

private let anchor = CGPoint(x: 500, y: 500)

func autoScrollTests() {
    test("velocity: dead zone, direction, growth and cap") {
        expectEqual(AutoScroller.velocity(offset: 0), 0, "centre")
        expectEqual(AutoScroller.velocity(offset: AutoScroller.deadZone), 0, "edge of dead zone")
        expectEqual(AutoScroller.velocity(offset: -AutoScroller.deadZone), 0, "edge of dead zone (negative)")
        expect(AutoScroller.velocity(offset: 50) > 0, "positive offset → positive speed")
        expect(AutoScroller.velocity(offset: -50) < 0, "negative offset → negative speed")
        expectEqual(AutoScroller.velocity(offset: -50), -AutoScroller.velocity(offset: 50), "symmetric")
        expect(AutoScroller.velocity(offset: 200) > AutoScroller.velocity(offset: 50), "farther is faster")
        expectEqual(AutoScroller.velocity(offset: 100_000), AutoScroller.maxSpeed, "capped")
    }

    test("click and move: click starts, pointer below scrolls down, next click stops") {
        let h = Harness(mode: .clickAndMove)
        expectEqual(h.scroller.middleDown(at: anchor), true, "down swallowed")
        expectEqual(h.starts.count, 1, "overlay shown")
        expectEqual(h.scroller.middleUp(at: anchor), true, "up swallowed")
        expectEqual(h.scroller.state, .active(anchor: anchor, toggled: true, moved: false), "toggled on")

        h.pointer = CGPoint(x: 500, y: 650)       // 150 pt below the anchor
        h.ticks(30)
        expect(h.totalScroll.dy < 0, "negative wheel delta = page scrolls down, got \(h.totalScroll.dy)")
        expectEqual(h.totalScroll.dx, 0, "no horizontal movement")

        expectEqual(h.scroller.middleDown(at: h.pointer), true, "stopping click swallowed")
        expectEqual(h.scroller.middleUp(at: h.pointer), true, "its up swallowed")
        expectEqual(h.scroller.state, .idle, "idle again")
        expectEqual(h.stops, 1, "overlay hidden once")
        expectEqual(h.replays.count, 0, "nothing replayed")
    }

    test("click and move: wheel click on a link passes through") {
        let h = Harness(mode: .clickAndMove)
        h.cursorIsHand = true
        expectEqual(h.scroller.middleDown(at: anchor), false, "down passes")
        expectEqual(h.scroller.middleUp(at: anchor), false, "up passes")
        expectEqual(h.starts.count, 0, "no autoscroll")
        expectEqual(h.scroller.state, .idle)
    }

    test("click and move: holding and dragging stops on release") {
        let h = Harness(mode: .clickAndMove)
        _ = h.scroller.middleDown(at: anchor)
        expectEqual(h.scroller.middleDragged(to: CGPoint(x: 500, y: 560)), true, "drag swallowed")
        expectEqual(h.scroller.middleUp(at: CGPoint(x: 500, y: 560)), true, "release swallowed")
        expectEqual(h.scroller.state, .idle, "stopped instead of toggling")
        expectEqual(h.stops, 1)
    }

    test("click and move: a left/right click stops it and both halves are swallowed") {
        let h = Harness(mode: .clickAndMove)
        _ = h.scroller.middleDown(at: anchor)
        _ = h.scroller.middleUp(at: anchor)
        expectEqual(h.scroller.otherButtonDown(), true, "click swallowed")
        expectEqual(h.scroller.otherButtonUp(), true, "its up swallowed")
        expectEqual(h.scroller.otherButtonUp(), false, "later ups pass")
        expectEqual(h.scroller.state, .idle)
        expectEqual(h.stops, 1)
    }

    test("left/right clicks are ignored when autoscroll is not toggled on") {
        let h = Harness(mode: .clickAndMove)
        expectEqual(h.scroller.otherButtonDown(), false, "idle")
        _ = h.scroller.middleDown(at: anchor)       // active but still held
        expectEqual(h.scroller.otherButtonDown(), false, "held, not toggled")
    }

    test("hold and drag: a plain wheel click is replayed unchanged") {
        let h = Harness(mode: .holdAndDrag)
        expectEqual(h.scroller.middleDown(at: anchor), true, "down held back")
        expectEqual(h.scroller.middleDragged(to: CGPoint(x: 503, y: 502)), true, "tiny jitter")
        expectEqual(h.scroller.middleUp(at: anchor), true, "up held back")
        expectEqual(h.replays.count, 1, "click replayed")
        expect(h.replays.first == anchor, "replayed at the original position")
        expectEqual(h.starts.count, 0, "never started")
        expectEqual(h.scroller.state, .idle)
    }

    test("hold and drag: dragging past the threshold scrolls until release") {
        let h = Harness(mode: .holdAndDrag)
        _ = h.scroller.middleDown(at: anchor)
        _ = h.scroller.middleDragged(to: CGPoint(x: 500, y: 520))
        expectEqual(h.starts.count, 1, "started after threshold")
        _ = h.scroller.middleDragged(to: CGPoint(x: 500, y: 380))   // keep dragging, above the anchor
        h.ticks(30)
        expect(h.totalScroll.dy > 0, "positive wheel delta = page scrolls up, got \(h.totalScroll.dy)")
        _ = h.scroller.middleUp(at: h.pointer)
        expectEqual(h.scroller.state, .idle, "stopped on release")
        expectEqual(h.replays.count, 0, "no replay after a drag")
    }

    test("while the wheel is held, drag events drive scrolling (session location is stale)") {
        // Regression: swallowed drag events don't update the session's pointer
        // location, so reading it while holding the wheel always gave the anchor.
        for mode in [AutoScrollMode.holdAndDrag, .clickAndMove] {
            let h = Harness(mode: mode)
            h.pointer = anchor                          // stale: never updates while held
            _ = h.scroller.middleDown(at: anchor)
            _ = h.scroller.middleDragged(to: CGPoint(x: 500, y: 520))
            _ = h.scroller.middleDragged(to: CGPoint(x: 500, y: 680))
            h.ticks(30)
            expect(h.totalScroll.dy < 0, "\(mode): should scroll down, got \(h.totalScroll.dy)")
            expect(h.scrollLocations.allSatisfy { $0 == CGPoint(x: 500, y: 680) },
                   "\(mode): posted at the drag position")
        }
    }

    test("after releasing in click-and-move, the real pointer drives scrolling again") {
        let h = Harness(mode: .clickAndMove)
        _ = h.scroller.middleDown(at: anchor)
        _ = h.scroller.middleDragged(to: CGPoint(x: 502, y: 503))   // jitter below threshold
        _ = h.scroller.middleUp(at: anchor)                          // toggles on
        h.pointer = CGPoint(x: 500, y: 300)
        h.ticks(30)
        expect(h.totalScroll.dy > 0, "follows the live pointer upwards, got \(h.totalScroll.dy)")
    }

    test("horizontal: pointer to the right scrolls right") {
        let h = Harness(mode: .clickAndMove)
        _ = h.scroller.middleDown(at: anchor)
        _ = h.scroller.middleUp(at: anchor)
        h.pointer = CGPoint(x: 650, y: 500)
        h.ticks(30)
        expect(h.totalScroll.dx < 0, "negative horizontal delta = scroll right, got \(h.totalScroll.dx)")
        expectEqual(h.totalScroll.dy, 0, "no vertical movement")
    }

    test("scroll events are posted at the pointer, never at the anchor") {
        // Regression: posting at the anchor warped the cursor back to it on every tick.
        let h = Harness(mode: .clickAndMove)
        _ = h.scroller.middleDown(at: anchor)
        _ = h.scroller.middleUp(at: anchor)
        h.pointer = CGPoint(x: 520, y: 700)
        h.ticks(5)
        expect(!h.scrollLocations.isEmpty, "something was posted")
        expect(h.scrollLocations.allSatisfy { $0 == h.pointer }, "posted at \(h.scrollLocations)")
    }

    test("inside the dead zone nothing is posted") {
        let h = Harness(mode: .clickAndMove)
        _ = h.scroller.middleDown(at: anchor)
        _ = h.scroller.middleUp(at: anchor)
        h.pointer = CGPoint(x: 505, y: 507)
        h.ticks(120)
        expectEqual(h.scrolls.count, 0)
    }

    test("slow speeds accumulate fractions instead of losing them") {
        let h = Harness(mode: .clickAndMove)
        _ = h.scroller.middleDown(at: anchor)
        _ = h.scroller.middleUp(at: anchor)
        h.pointer = CGPoint(x: 500, y: 500 + AutoScroller.deadZone + 2)   // very slow
        h.ticks(600)                                                      // 10 s
        let expected = AutoScroller.velocity(offset: AutoScroller.deadZone + 2) * 10
        let actual = Double(-h.totalScroll.dy)
        expect(abs(actual - expected) <= 1, "expected ≈\(expected) px, got \(actual)")
    }

    test("cancel() stops scrolling and hides the anchor") {
        let h = Harness(mode: .clickAndMove)
        _ = h.scroller.middleDown(at: anchor)
        _ = h.scroller.middleUp(at: anchor)
        h.scroller.cancel()
        expectEqual(h.scroller.state, .idle)
        expectEqual(h.stops, 1)
        h.pointer = CGPoint(x: 500, y: 800)
        h.ticks(10)
        expectEqual(h.scrolls.count, 0, "no ticks after cancel")
    }

    test("ScrollFlip's own events are recognised by their marker") {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: 5, wheel2: 0, wheel3: 0)!
        expectEqual(SyntheticEvent.isOurs(event), false, "foreign event")
        event.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
        expectEqual(SyntheticEvent.isOurs(event), true, "marked event")
    }
}
