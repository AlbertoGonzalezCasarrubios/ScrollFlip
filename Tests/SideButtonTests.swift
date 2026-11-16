import CoreGraphics

private let safari = "com.apple.Safari"
private let chrome = "com.google.Chrome"

func sideButtonTests() {
    test("Apple apps, Firefox and Opera get the swipe gesture") {
        for id in [safari, "com.apple.finder", "com.apple.Preview", "org.mozilla.firefox", "com.operasoftware.Opera"] {
            expectEqual(NavigationStrategy.forApp(bundleID: id), .swipe, id)
        }
    }

    test("apps that understand buttons 4/5 natively get them untouched") {
        for id in [chrome, "com.microsoft.VSCode", "com.microsoft.edgemac", "company.thebrowser.Browser"] {
            expectEqual(NavigationStrategy.forApp(bundleID: id), .passThrough, id)
        }
        expectEqual(NavigationStrategy.forApp(bundleID: nil), .passThrough, "no frontmost app")
    }

    test("button 4 is Back and button 5 is Forward") {
        let mapper = SideButtonMapper()
        expectEqual(mapper.decide(button: 3, isDown: true, bundleID: safari), .navigate(.back))
        expectEqual(mapper.decide(button: 4, isDown: true, bundleID: safari), .navigate(.forward))
    }

    test("swap option exchanges Back and Forward") {
        let mapper = SideButtonMapper()
        mapper.swapButtons = true
        expectEqual(mapper.decide(button: 3, isDown: true, bundleID: safari), .navigate(.forward))
        expectEqual(mapper.decide(button: 4, isDown: true, bundleID: safari), .navigate(.back))
    }

    test("the matching button-up is swallowed only after a swallowed button-down") {
        let mapper = SideButtonMapper()
        expectEqual(mapper.decide(button: 3, isDown: false, bundleID: safari), .passThrough, "stray up")
        _ = mapper.decide(button: 3, isDown: true, bundleID: safari)
        expectEqual(mapper.decide(button: 3, isDown: false, bundleID: safari), .consume, "matching up")
        expectEqual(mapper.decide(button: 3, isDown: false, bundleID: safari), .passThrough, "second up")
    }

    test("switching apps between down and up still swallows the up") {
        let mapper = SideButtonMapper()
        _ = mapper.decide(button: 4, isDown: true, bundleID: safari)
        expectEqual(mapper.decide(button: 4, isDown: false, bundleID: chrome), .consume)
    }

    test("pass-through apps receive both down and up") {
        let mapper = SideButtonMapper()
        expectEqual(mapper.decide(button: 3, isDown: true, bundleID: chrome), .passThrough, "down")
        expectEqual(mapper.decide(button: 3, isDown: false, bundleID: chrome), .passThrough, "up")
    }

    test("middle button and other buttons are never touched") {
        let mapper = SideButtonMapper()
        for button: Int64 in [0, 1, 2, 5, 6] {
            expectEqual(mapper.decide(button: button, isDown: true, bundleID: safari), .passThrough, "button \(button)")
        }
    }

    test("handle() navigates and swallows; it does nothing for pass-through apps") {
        let mapper = SideButtonMapper()
        var performed: [NavigationDirection] = []
        mapper.performNavigation = { performed.append($0) }

        mapper.frontmostBundleID = { safari }
        expectEqual(mapper.handle(button: 3, isDown: true), true, "down swallowed")
        expectEqual(mapper.handle(button: 3, isDown: false), true, "up swallowed")

        mapper.frontmostBundleID = { chrome }
        expectEqual(mapper.handle(button: 4, isDown: true), false, "chrome down passes")
        expectEqual(mapper.handle(button: 4, isDown: false), false, "chrome up passes")

        expectEqual(performed, [.back])
    }

    test("swipe gesture events carry the navigation-swipe fields") {
        let began = SwipeGesture.makeEvent(.back, ended: false)
        let ended = SwipeGesture.makeEvent(.forward, ended: true)
        guard let began, let ended else { return fail("could not create gesture events") }

        let f = SwipeGesture.field
        expectEqual(began.type.rawValue, SwipeGesture.gestureEventType, "event type")
        expectEqual(began.getIntegerValueField(f(SwipeGesture.hidTypeField)), SwipeGesture.navigationSwipeHIDType, "HID type")
        expectEqual(began.getIntegerValueField(f(SwipeGesture.phaseField)), SwipeGesture.phaseBegan, "began phase")
        expectEqual(began.getIntegerValueField(f(SwipeGesture.directionField)), 0, "no direction on began")
        expectEqual(ended.getIntegerValueField(f(SwipeGesture.phaseField)), SwipeGesture.phaseEnded, "ended phase")
        expectEqual(ended.getIntegerValueField(f(SwipeGesture.directionField)), SwipeGesture.directionRight, "forward = right")

        let back = SwipeGesture.makeEvent(.back, ended: true)
        expectEqual(back?.getIntegerValueField(f(SwipeGesture.directionField)), SwipeGesture.directionLeft, "back = left")
    }
}
