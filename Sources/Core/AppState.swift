import Foundation
import ServiceManagement

enum SettingsTab: Hashable { case general, tryIt, language }

/// Abstraction over SMAppService so tests don't touch the real login items.
protocol LoginItemControlling {
    var isEnabled: Bool { get }
    func register() throws
    func unregister() throws
}

struct SystemLoginItem: LoginItemControlling {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

/// Single source of truth for settings. Persists to UserDefaults and pushes
/// every change to the ScrollInverter. Also holds the live demo samples.
final class AppState: ObservableObject {
    static let speedSteps: [Double] = [0.5, 0.75, 1, 1.5, 2, 3, 4]
    static let defaultSpeed: Double = 1

    let inverter: ScrollInverter
    let sideButtons: SideButtonMapper
    let autoScroller: AutoScroller
    private let defaults: UserDefaults
    private let loginItem: LoginItemControlling

    enum Key {
        static let enabled = "enabled"
        static let vertical = "invertVertical"
        static let horizontal = "invertHorizontal"
        static let speed = "speed"
        static let language = "language"
        static let sideButtons = "sideButtons"
        static let swapSideButtons = "swapSideButtons"
        static let autoScroll = "autoScroll"
        static let autoScrollMode = "autoScrollMode"
        static let didShowWelcome = "didShowDemo"
    }

    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: Key.enabled); inverter.isEnabled = enabled }
    }
    @Published var invertVertical: Bool {
        didSet { defaults.set(invertVertical, forKey: Key.vertical); inverter.invertVertical = invertVertical }
    }
    @Published var invertHorizontal: Bool {
        didSet { defaults.set(invertHorizontal, forKey: Key.horizontal); inverter.invertHorizontal = invertHorizontal }
    }
    @Published var speed: Double {
        didSet { defaults.set(speed, forKey: Key.speed); inverter.speed = speed }
    }
    /// Off by default: when off, ScrollFlip has no tap on mouse buttons at all.
    @Published var sideButtonsEnabled: Bool {
        didSet { defaults.set(sideButtonsEnabled, forKey: Key.sideButtons); applySideButtons() }
    }
    @Published var swapSideButtons: Bool {
        didSet { defaults.set(swapSideButtons, forKey: Key.swapSideButtons); sideButtons.swapButtons = swapSideButtons }
    }
    /// Off by default: when off, ScrollFlip has no tap on the middle button.
    @Published var autoScrollEnabled: Bool {
        didSet { defaults.set(autoScrollEnabled, forKey: Key.autoScroll); applyAutoScroll() }
    }
    @Published var autoScrollMode: AutoScrollMode {
        didSet { defaults.set(autoScrollMode.rawValue, forKey: Key.autoScrollMode); autoScroller.mode = autoScrollMode }
    }
    @Published var language: Language {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }

    @Published private(set) var launchAtLogin = false
    @Published var loginItemError = false
    @Published var permissionGranted = false {
        didSet { applySideButtons(); applyAutoScroll() }
    }
    @Published var selectedTab = SettingsTab.general

    // Live samples for the "Try it" tab (memory only).
    @Published var mouseSample: ScrollSample?
    @Published var trackpadSample: ScrollSample?
    @Published var mouseTick = 0
    @Published var trackpadTick = 0

    init(inverter: ScrollInverter,
         sideButtons: SideButtonMapper = SideButtonMapper(),
         autoScroller: AutoScroller = AutoScroller(),
         defaults: UserDefaults = .standard,
         loginItem: LoginItemControlling = SystemLoginItem()) {
        self.inverter = inverter
        self.sideButtons = sideButtons
        self.autoScroller = autoScroller
        self.defaults = defaults
        self.loginItem = loginItem
        defaults.register(defaults: [
            Key.enabled: true,
            Key.vertical: true,
            Key.horizontal: false,
            Key.speed: Self.defaultSpeed,
            Key.language: Language.system.rawValue,
            Key.sideButtons: false,
            Key.swapSideButtons: false,
            Key.autoScroll: false,
            Key.autoScrollMode: AutoScrollMode.clickAndMove.rawValue,
        ])
        enabled = defaults.bool(forKey: Key.enabled)
        invertVertical = defaults.bool(forKey: Key.vertical)
        invertHorizontal = defaults.bool(forKey: Key.horizontal)
        let storedSpeed = defaults.double(forKey: Key.speed)
        speed = Self.speedSteps.contains(storedSpeed) ? storedSpeed : Self.defaultSpeed
        language = Language(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .system
        sideButtonsEnabled = defaults.bool(forKey: Key.sideButtons)
        swapSideButtons = defaults.bool(forKey: Key.swapSideButtons)
        autoScrollEnabled = defaults.bool(forKey: Key.autoScroll)
        autoScrollMode = AutoScrollMode(rawValue: defaults.string(forKey: Key.autoScrollMode) ?? "") ?? .clickAndMove

        // didSet does not run inside init, so sync the inverter by hand.
        inverter.isEnabled = enabled
        inverter.invertVertical = invertVertical
        inverter.invertHorizontal = invertHorizontal
        inverter.speed = speed
        sideButtons.swapButtons = swapSideButtons
        autoScroller.mode = autoScrollMode
        refreshLaunchAtLogin()
    }

    /// The middle-button tap only exists while autoscroll is on and permitted.
    private func applyAutoScroll() {
        if autoScrollEnabled && permissionGranted {
            autoScroller.start()
        } else {
            autoScroller.stopTap()
        }
    }

    /// The side-button tap only exists while the feature is on and permitted.
    private func applySideButtons() {
        if sideButtonsEnabled && permissionGranted {
            sideButtons.start()
        } else {
            sideButtons.stop()
        }
    }

    /// True only the first time the app is launched.
    func consumeFirstLaunch() -> Bool {
        if defaults.bool(forKey: Key.didShowWelcome) { return false }
        defaults.set(true, forKey: Key.didShowWelcome)
        return true
    }

    func t(_ key: L) -> String { key.text(language.resolved) }

    // MARK: Launch at login

    func refreshLaunchAtLogin() {
        launchAtLogin = loginItem.isEnabled
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try loginItem.register() } else { try loginItem.unregister() }
            loginItemError = false
        } catch {
            loginItemError = true
        }
        refreshLaunchAtLogin()
    }

    // MARK: Demo

    func record(_ sample: ScrollSample) {
        if sample.isContinuous {
            trackpadSample = sample
            trackpadTick &+= 1
        } else {
            mouseSample = sample
            mouseTick &+= 1
        }
    }

    func clearSamples() {
        mouseSample = nil
        trackpadSample = nil
    }
}
