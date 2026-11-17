import Foundation

private final class FakeLoginItem: LoginItemControlling {
    var isEnabled = false
    var shouldFail = false
    struct Failure: Error {}

    func register() throws {
        if shouldFail { throw Failure() }
        isEnabled = true
    }

    func unregister() throws {
        if shouldFail { throw Failure() }
        isEnabled = false
    }
}

/// Runs `body` with a throw-away UserDefaults domain that is deleted afterwards.
private func withTemporaryDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
    let name = "ScrollFlipTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    try body(defaults)
}

func appStateTests() {
    test("fresh install uses the documented defaults") {
        withTemporaryDefaults { defaults in
            let inverter = ScrollInverter()
            let state = AppState(inverter: inverter, defaults: defaults, loginItem: FakeLoginItem())
            expectEqual(state.enabled, true, "enabled")
            expectEqual(state.invertVertical, true, "invertVertical")
            expectEqual(state.invertHorizontal, false, "invertHorizontal")
            expectEqual(state.speed, AppState.defaultSpeed, "speed")
            expectEqual(state.language, .system, "language")
            expectEqual(state.launchAtLogin, false, "launchAtLogin")
            expectEqual(state.sideButtonsEnabled, false, "side buttons off by default")
            expectEqual(state.sideButtons.isRunning, false, "no button tap by default")
            expectEqual(state.autoScrollEnabled, false, "autoscroll off by default")
            expectEqual(state.autoScrollMode, .clickAndMove, "Windows-style mode by default")
            expectEqual(state.autoScroller.isRunning, false, "no middle-button tap by default")
            expectEqual(inverter.speed, AppState.defaultSpeed, "inverter speed synced")
        }
    }

    test("changes are pushed to the inverter immediately") {
        withTemporaryDefaults { defaults in
            let inverter = ScrollInverter()
            let state = AppState(inverter: inverter, defaults: defaults, loginItem: FakeLoginItem())
            state.enabled = false
            state.invertVertical = false
            state.invertHorizontal = true
            state.speed = 3
            expectEqual(inverter.isEnabled, false, "isEnabled")
            expectEqual(inverter.invertVertical, false, "invertVertical")
            expectEqual(inverter.invertHorizontal, true, "invertHorizontal")
            expectEqual(inverter.speed, 3, "speed")
        }
    }

    test("settings survive a relaunch") {
        withTemporaryDefaults { defaults in
            let first = AppState(inverter: ScrollInverter(), defaults: defaults, loginItem: FakeLoginItem())
            first.enabled = false
            first.invertHorizontal = true
            first.speed = 1.5
            first.language = .english
            first.swapSideButtons = true
            first.autoScrollMode = .holdAndDrag

            let inverter = ScrollInverter()
            let relaunched = AppState(inverter: inverter, defaults: defaults, loginItem: FakeLoginItem())
            expectEqual(relaunched.enabled, false, "enabled")
            expectEqual(relaunched.invertHorizontal, true, "invertHorizontal")
            expectEqual(relaunched.speed, 1.5, "speed")
            expectEqual(relaunched.language, .english, "language")
            expectEqual(relaunched.swapSideButtons, true, "swapSideButtons")
            expectEqual(relaunched.sideButtons.swapButtons, true, "mapper synced on launch")
            expectEqual(relaunched.autoScrollMode, .holdAndDrag, "autoScrollMode")
            expectEqual(relaunched.autoScroller.mode, .holdAndDrag, "scroller synced on launch")
            expectEqual(inverter.isEnabled, false, "inverter synced on launch")
            expectEqual(inverter.speed, 1.5, "inverter speed synced on launch")
        }
    }

    test("corrupted stored values fall back to defaults") {
        withTemporaryDefaults { defaults in
            defaults.set(7.3, forKey: AppState.Key.speed)
            defaults.set("klingon", forKey: AppState.Key.language)
            defaults.set("sideways", forKey: AppState.Key.autoScrollMode)
            let state = AppState(inverter: ScrollInverter(), defaults: defaults, loginItem: FakeLoginItem())
            expectEqual(state.speed, AppState.defaultSpeed, "speed")
            expectEqual(state.language, .system, "language")
            expectEqual(state.autoScrollMode, .clickAndMove, "autoScrollMode")
        }
    }

    test("first-launch flag is consumed exactly once") {
        withTemporaryDefaults { defaults in
            let state = AppState(inverter: ScrollInverter(), defaults: defaults, loginItem: FakeLoginItem())
            expectEqual(state.consumeFirstLaunch(), true, "first call")
            expectEqual(state.consumeFirstLaunch(), false, "second call")
        }
    }

    test("launch at login reflects the system and reports failures") {
        withTemporaryDefaults { defaults in
            let login = FakeLoginItem()
            let state = AppState(inverter: ScrollInverter(), defaults: defaults, loginItem: login)
            state.setLaunchAtLogin(true)
            expectEqual(state.launchAtLogin, true, "enabled")
            expectEqual(state.loginItemError, false, "no error")

            login.shouldFail = true
            state.setLaunchAtLogin(false)
            expectEqual(state.launchAtLogin, true, "unchanged after failure")
            expectEqual(state.loginItemError, true, "error reported")
        }
    }

    test("demo samples are routed by device and can be cleared") {
        withTemporaryDefaults { defaults in
            let state = AppState(inverter: ScrollInverter(), defaults: defaults, loginItem: FakeLoginItem())
            state.record(ScrollSample(isContinuous: false, axis: .vertical, input: 1, output: -1))
            state.record(ScrollSample(isContinuous: true, axis: .vertical, input: 2, output: 2))
            expect(state.mouseSample?.input == 1, "mouse sample")
            expect(state.trackpadSample?.input == 2, "trackpad sample")
            expectEqual(state.mouseTick, 1, "mouse tick")
            expectEqual(state.trackpadTick, 1, "trackpad tick")
            state.clearSamples()
            expect(state.mouseSample == nil && state.trackpadSample == nil, "cleared")
        }
    }

    test("side-button tap never starts without permission") {
        withTemporaryDefaults { defaults in
            let state = AppState(inverter: ScrollInverter(), defaults: defaults, loginItem: FakeLoginItem())
            state.sideButtonsEnabled = true
            state.autoScrollEnabled = true
            expectEqual(state.sideButtons.isRunning, false, "permission not granted yet")
            expectEqual(state.autoScroller.isRunning, false, "autoscroll: permission not granted yet")
            state.sideButtonsEnabled = false
            expectEqual(state.sideButtons.isRunning, false, "turned off")
        }
    }

    test("speed steps are sorted and include the default") {
        expectEqual(AppState.speedSteps, AppState.speedSteps.sorted(), "sorted")
        expect(AppState.speedSteps.contains(AppState.defaultSpeed), "contains default")
        expect(AppState.speedSteps.allSatisfy { $0 > 0 }, "all positive")
    }
}
