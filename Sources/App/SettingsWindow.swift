import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState
    var onOpenAccessibility: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !state.permissionGranted {
                Banner(symbol: "exclamationmark.triangle.fill", tint: .orange,
                       text: state.t(.permissionBanner),
                       buttonTitle: state.t(.openSettings), action: onOpenAccessibility)
            } else if !state.enabled {
                Banner(symbol: "pause.circle.fill", tint: .secondary,
                       text: state.t(.pausedBanner),
                       buttonTitle: state.t(.enable), action: { state.enabled = true })
            }

            TabView(selection: $state.selectedTab) {
                GeneralTab(state: state)
                    .tabItem { Text(state.t(.tabGeneral)) }
                    .tag(SettingsTab.general)
                TryTab(state: state)
                    .tabItem { Text(state.t(.tabTry)) }
                    .tag(SettingsTab.tryIt)
                LanguageTab(state: state)
                    .tabItem { Text(state.t(.tabLanguage)) }
                    .tag(SettingsTab.language)
            }
        }
        .padding(16)
        .frame(width: 560, height: 680)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject var state: AppState

    private var speedIndex: Binding<Double> {
        Binding(
            get: {
                let i = AppState.speedSteps.firstIndex(of: state.speed)
                    ?? AppState.speedSteps.firstIndex(of: AppState.defaultSpeed)!
                return Double(i)
            },
            set: { state.speed = AppState.speedSteps[Int($0.rounded())] }
        )
    }

    private var speedLabel: String {
        let s = state.speed
        let number = s == s.rounded() ? String(Int(s)) : String(s)
        return s == AppState.defaultSpeed ? "\(number)× (\(state.t(.speedDefault)))" : "\(number)×"
    }

    var body: some View {
        Form {
            Section {
                Toggle(state.t(.enabled), isOn: $state.enabled)
            }

            Section(state.t(.sectionWheel)) {
                Toggle(state.t(.invertVertical), isOn: $state.invertVertical)
                Toggle(state.t(.invertHorizontal), isOn: $state.invertHorizontal)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(state.t(.speed))
                        Spacer()
                        Text(speedLabel)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Button(state.t(.reset)) { state.speed = AppState.defaultSpeed }
                            .disabled(state.speed == AppState.defaultSpeed)
                    }
                    Slider(value: speedIndex,
                           in: 0...Double(AppState.speedSteps.count - 1),
                           step: 1) {
                        EmptyView()
                    } minimumValueLabel: {
                        Image(systemName: "tortoise")
                    } maximumValueLabel: {
                        Image(systemName: "hare")
                    }
                    Text(state.t(.speedNote))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section(state.t(.sectionButtons)) {
                Toggle(state.t(.sideButtonsToggle), isOn: $state.sideButtonsEnabled)
                Toggle(state.t(.swapButtons), isOn: $state.swapSideButtons)
                    .disabled(!state.sideButtonsEnabled)
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.t(.sideButtonsNote))
                    Label(state.t(.sideButtonsPrivacy), systemImage: "lock.shield")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Section(state.t(.sectionStartup)) {
                Toggle(state.t(.launchAtLogin), isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
                if state.loginItemError {
                    Text(state.t(.loginError))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Try it

private struct TryTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.t(.tryTitle)).font(.title3.bold())
                Text(state.t(.tryIntro))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                DeviceCard(state: state, title: state.t(.mouse), symbol: "computermouse",
                           sample: state.mouseSample, tick: state.mouseTick)
                DeviceCard(state: state, title: state.t(.trackpad), symbol: "rectangle.and.hand.point.up.left",
                           sample: state.trackpadSample, tick: state.trackpadTick)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(1...80, id: \.self) { i in
                        HStack {
                            Text("\(state.t(.row)) \(i)").monospacedDigit()
                            Spacer()
                            if i == 1 { Text(state.t(.scrollHere)).foregroundStyle(.secondary) }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(i.isMultiple(of: 2) ? Color.secondary.opacity(0.06) : .clear)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.25)))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            SideButtonTrial(state: state)

            Label(state.t(.privacyNote), systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
    }
}

/// Lets people without side buttons check Back/Forward: after a countdown
/// (time to switch to Safari or Finder) it posts a synthetic button 4/5 click.
private struct SideButtonTrial: View {
    @ObservedObject var state: AppState
    @State private var countdown: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(state.t(.tryButtonsTitle)).font(.headline)
            HStack(spacing: 10) {
                Button { start(.back) } label: { Label(state.t(.tryBack), systemImage: "chevron.left") }
                Button { start(.forward) } label: { Label(state.t(.tryForward), systemImage: "chevron.right") }
                if let countdown {
                    Text("\(state.t(.countdown)) \(countdown)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!state.sideButtonsEnabled || !state.permissionGranted || countdown != nil)
            Text(state.sideButtonsEnabled ? state.t(.tryButtonsIntro) : state.t(.tryButtonsDisabled))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func start(_ direction: NavigationDirection) {
        countdown = 3
        tick(direction)
    }

    private func tick(_ direction: NavigationDirection) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let current = countdown else { return }
            if current <= 1 {
                countdown = nil
                SideButtonMapper.simulateClick(direction)
            } else {
                countdown = current - 1
                tick(direction)
            }
        }
    }
}

private struct DeviceCard: View {
    @ObservedObject var state: AppState
    let title: String
    let symbol: String
    let sample: ScrollSample?
    let tick: Int

    @State private var lit = false

    private func badge(for sample: ScrollSample) -> (String, Bool) {
        if sample.wasInverted { return (state.t(.badgeInverted), true) }
        if sample.wasModified { return (state.t(.badgeSpeed), true) }
        return (state.t(.badgeUnchanged), false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.title2)
                Text(title).font(.headline).lineLimit(1)
            }

            if let sample {
                let (text, highlighted) = badge(for: sample)
                HStack(spacing: 8) {
                    arrow(sample.input, sample.axis)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    arrow(sample.output, sample.axis)
                    Spacer()
                    Text(text)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(highlighted
                                                   ? Color.accentColor.opacity(0.2)
                                                   : Color.secondary.opacity(0.15)))
                }
                Text(state.t(.cardCaption))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(state.t(.noMovement))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(lit ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: lit ? 2 : 1))
        .onChange(of: tick) { current in
            lit = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard current == tick else { return } // still scrolling
                withAnimation(.easeOut(duration: 0.4)) { lit = false }
            }
        }
    }

    private func arrow(_ value: Double, _ axis: ScrollSample.Axis) -> some View {
        let name: String
        switch (axis, value > 0) {
        case (.vertical, true): name = "arrow.up.circle.fill"
        case (.vertical, false): name = "arrow.down.circle.fill"
        case (.horizontal, true): name = "arrow.left.circle.fill"
        case (.horizontal, false): name = "arrow.right.circle.fill"
        }
        return Image(systemName: name).font(.title)
    }
}

// MARK: - Language

private struct LanguageTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            Section(state.t(.languageTitle)) {
                Picker(state.t(.languageTitle), selection: $state.language) {
                    Text(state.t(.languageSystem)).tag(Language.system)
                    Text("Español").tag(Language.spanish)
                    Text("English").tag(Language.english)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                Text(state.t(.languageNote))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shared

private struct Banner: View {
    let symbol: String
    let tint: Color
    let text: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(buttonTitle, action: action)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.12)))
    }
}
