import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let inverter = ScrollInverter()
    private lazy var state = AppState(inverter: inverter)
    private var statusItem: NSStatusItem!
    private var permissionTimer: Timer?
    private var settingsWindow: NSWindow?
    private var iconSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "ScrollFlip")
        image?.isTemplate = true
        statusItem.button?.image = image
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // The icon looks dimmed while paused or without permission.
        iconSubscription = Publishers.CombineLatest(state.$enabled, state.$permissionGranted)
            .sink { [weak self] enabled, granted in
                self?.statusItem.button?.appearsDisabled = !(enabled && granted)
            }

        if inverter.start() {
            state.permissionGranted = true
        } else {
            // First run: macOS shows the Accessibility prompt.
            CGRequestPostEventAccess()
            waitForPermission()
        }

        if state.consumeFirstLaunch() {
            showSettings(tab: .tryIt)
        }
    }

    /// Retries every 2 s until the user grants the permission.
    private func waitForPermission() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            if self.inverter.start() {
                timer.invalidate()
                self.state.permissionGranted = true
            }
        }
    }

    // MARK: - Menu (rebuilt every time it opens, so it always reflects the real state)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        state.refreshLaunchAtLogin()

        let status: L = !state.permissionGranted ? .statusNoPermission
            : (state.enabled ? .statusActive : .statusPaused)
        let statusLine = NSMenuItem(title: state.t(status), action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())

        if !state.permissionGranted {
            menu.addItem(item(.menuOpenAccessibility, #selector(openAccessibilitySettings)))
        }
        menu.addItem(item(.menuSettings, #selector(openSettingsFromMenu), key: ","))
        menu.addItem(.separator())

        menu.addItem(item(.enabled, #selector(toggleEnabled), on: state.enabled))
        menu.addItem(item(.invertVertical, #selector(toggleVertical), on: state.invertVertical))
        menu.addItem(item(.invertHorizontal, #selector(toggleHorizontal), on: state.invertHorizontal))
        menu.addItem(.separator())
        menu.addItem(item(.launchAtLogin, #selector(toggleLaunchAtLogin), on: state.launchAtLogin))
        menu.addItem(.separator())
        menu.addItem(item(.quit, #selector(quit), key: "q"))
    }

    private func item(_ key: L, _ action: Selector, on: Bool? = nil, key equivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: state.t(key), action: action, keyEquivalent: equivalent)
        item.target = self
        if let on { item.state = on ? .on : .off }
        return item
    }

    @objc private func toggleEnabled() { state.enabled.toggle() }
    @objc private func toggleVertical() { state.invertVertical.toggle() }
    @objc private func toggleHorizontal() { state.invertHorizontal.toggle() }
    @objc private func toggleLaunchAtLogin() { state.setLaunchAtLogin(!state.launchAtLogin) }
    @objc private func openSettingsFromMenu() { showSettings(tab: nil) }

    @objc private func openAccessibilitySettings() {
        CGRequestPostEventAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        waitForPermission()
    }

    @objc private func quit() {
        inverter.stop()
        NSApp.terminate(nil)
    }

    // MARK: - Settings window

    private func showSettings(tab: SettingsTab?) {
        if let tab { state.selectedTab = tab }
        if settingsWindow == nil {
            let view = SettingsView(state: state,
                                    onOpenAccessibility: { [weak self] in self?.openAccessibilitySettings() })
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "ScrollFlip"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        // The inverter only reports events while this window is open.
        inverter.observer = { [weak self] sample in self?.state.record(sample) }
        state.refreshLaunchAtLogin()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        inverter.observer = nil
        state.clearSamples()
    }
}
