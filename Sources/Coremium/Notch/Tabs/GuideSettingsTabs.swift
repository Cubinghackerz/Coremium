import CoremiumCore
import AppKit
import SwiftUI

struct GuideTab: View {
    var body: some View {
        FlexScroll {
            VStack(alignment: .leading, spacing: 10) {
                Card(padding: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(Pitch.headline).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white)
                        Text(Pitch.subline).font(.system(size: 11.5, design: .rounded)).foregroundColor(Theme.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Card(padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "The four choices for every app")
                        RuleLegend()
                        Text("Click a choice to set it; click it again to go back to following the mode.")
                            .font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim)
                    }
                }
                Card(padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Modes")
                        ForEach(PerformanceMode.allCases, id: \.self) { mode in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: mode.symbol).foregroundColor(mode.tint).frame(width: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(mode.label).font(.system(size: 11.5, weight: .semibold, design: .rounded)).foregroundColor(.white)
                                    Text(mode.summary).font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        Text("Automatic vs Yield: Automatic is a mode that picks the profile. Yield is a choice for one app: \"step aside when something else is boosted\".")
                            .font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Card(padding: 12) {
                    VStack(alignment: .leading, spacing: 7) {
                        SectionLabel(text: "Good to know")
                        tip("Hover the notch for a moment to open this panel. While a game is in front the pill ignores the mouse; use the menu-bar chip icon then.")
                        tip("Advanced shows the numbers: per-core load, memory, process counts, timers and why each rule applies.")
                        tip("Fullscreen fix adds an invisible 2-pixel window, only while an app is fullscreen, so macOS composites normally. It cures fullscreen stutter on 120 Hz MacBooks, mostly on macOS 27. Ordinary windows are left alone.")
                        tip("Coremium can't push the fast cores past what macOS allows: Boost works by clearing the way. It only affects your own apps, can't see helper services macOS starts for an app, and can't measure power or exact temperature.")
                        tip("GPU: macOS has no public way to lower another app's GPU priority, so Coremium shows who is using the GPU (\"GPU heavy\") and says so in its decisions instead of guessing.")
                        tip("If your Mac isn't overloaded there's nothing to fix, and Coremium will simply have little to move.")
                    }
                }
                TrustCard()
                Card(padding: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "If something looks wrong")
                        Text("Pause Coremium, use Restore in Settings, or quit it: all put everything back instantly. From Terminal:")
                            .font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim)
                        Text("/Applications/Coremium.app/Contents/MacOS/Coremium --restore-all")
                            .font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color.black.opacity(0.4)))
                    }
                }
            }
        }
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "circle.fill").font(.system(size: 4)).foregroundColor(Theme.accent).padding(.top, 5)
            Text(text).font(.system(size: 11, design: .rounded)).foregroundColor(Theme.textDim).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SettingsTab: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var ui: NotchUIState
    @State private var confirmReset = false
    @State private var copiedDiagnostics = false

    var body: some View {
        FlexScroll {
            VStack(alignment: .leading, spacing: 10) {
                Card(padding: 12) {
                    VStack(alignment: .leading, spacing: 11) {
                        SectionLabel(text: "General")
                        SettingRow(title: "Advanced mode", detail: "Show the numbers: per-core load, memory, process counts, timers, and why each rule applies.",
                                   isOn: $ui.advanced)
                        SettingRow(title: "Show indicators in the notch", detail: "The mode icon and status dot beside the notch. Turn off to keep the notch looking untouched; hover it or use the menu-bar icon as usual.",
                                   isOn: $ui.showIndicators)
                        SettingRow(title: "Check for updates", detail: "Once a day Coremium asks GitHub if there's a newer version and offers to install it. This is its only network access.",
                                   isOn: Binding(get: { Updater.shared.enabled }, set: { Updater.shared.enabled = $0; if $0 { Updater.shared.check() } }))
                        SettingRow(title: "Save battery when unplugged", detail: "On battery, apps working hard in the background move to the efficiency cores even without a boost.",
                                   isOn: $engine.rules.saveBatteryWhenUnplugged)
                        SettingRow(title: "Show decisions in the notch", detail: "Each change Coremium makes drops out of the notch for three seconds. Clicks pass straight through it.",
                                   isOn: $ui.decisionToasts)
                        SettingRow(title: "Open at login", detail: "Start quietly at login so your apps are protected from the start.",
                                   isOn: Binding(get: { engine.launchAtLogin }, set: { engine.setLaunchAtLogin($0) }))
                        SettingRow(title: "Pause Coremium", detail: "Puts every app back to full speed until you turn this off.", isOn: $engine.paused)
                    }
                }
                Card(padding: 12) {
                    VStack(alignment: .leading, spacing: 11) {
                        SectionLabel(text: "Performance")
                        SettingRow(title: "Adapt Automatic to CPU pressure",
                                   detail: "Waits for sustained CPU load, then moves busy background apps aside. Preserves busy builds, renders, and local models; your per-app choices still win.",
                                   isOn: $engine.rules.adaptiveAutomatic)
                        SettingRow(title: "Fullscreen fix", detail: "Stops fullscreen stutter on 120 Hz MacBooks with an invisible 2-pixel window, only while an app is fullscreen.",
                                   badge: FullscreenFix.isRecommended ? "Recommended" : "Experimental", isOn: $engine.rules.fullscreenFixEnabled)
                        SettingRow(title: "Protect a busy boosted app in the background", detail: "Keeps protecting a game or render that runs while you check something else.",
                                   isOn: $engine.rules.boostWhenBusy)
                        SettingRow(title: "Also move other heavy apps aside during a boost",
                                   detail: "Any app using more than \(String(format: "%.2f", engine.rules.heavyThresholdPercent / 100)) cores moves to the efficiency cores, even if unlisted.",
                                   isOn: $engine.rules.demoteHeavyApps)
                        SettingRow(title: "Keep the display awake during a boost", detail: "Stops the screen dimming mid-game or mid-render.",
                                   isOn: $engine.rules.keepDisplayAwakeDuringBoost)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Return to normal after").font(.system(size: 12.5, weight: .medium, design: .rounded)).foregroundColor(.white)
                                Text("How long to keep protecting after you leave the boosted app.")
                                    .font(.system(size: 11, design: .rounded)).foregroundColor(Theme.textDim)
                            }
                            Spacer(minLength: 8)
                            Slider(value: $engine.rules.graceSeconds, in: 15...300, step: 15).frame(width: 110)
                            Text(formatDuration(engine.rules.graceSeconds)).font(.system(size: 11, design: .rounded))
                                .foregroundColor(Theme.textDim).frame(width: 48, alignment: .trailing)
                        }
                    }
                }
                Card(padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "App index and maintenance")
                        HStack {
                            Text(engine.isIndexing ? "Updating…" : indexText).font(.system(size: 11.5, design: .rounded)).foregroundColor(.white)
                                .lineLimit(2)
                            Spacer()
                            Button("Rescan") { engine.rescan() }.buttonStyle(GhostButtonStyle()).disabled(engine.isIndexing)
                        }
                        Text("Coremium reads your apps directly (including Steam games) and watches your app folders, so it never waits on Spotlight.")
                            .font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Button("Restore all apps now") { engine.restoreAllNow() }.buttonStyle(GhostButtonStyle())
                            Button("Welcome tour") { ui.showingTour = true }.buttonStyle(GhostButtonStyle())
                            Button("Reset settings…") { confirmReset = true }.buttonStyle(GhostButtonStyle())
                            Spacer(minLength: 0)
                        }
                        HStack {
                            Text("Coremium \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · MIT license · not affiliated with Apple")
                                .font(.system(size: 10, design: .rounded)).foregroundColor(Theme.textDim)
                            Spacer(minLength: 6)
                            Button(copiedDiagnostics ? "Copied" : "Copy diagnostics") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(engine.diagnosticsReport(), forType: .string)
                                copiedDiagnostics = true
                            }
                            .buttonStyle(.plain).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.7))
                            .help("Copies versions, current state and the local log of slow moments, for a bug report. Nothing is sent.")
                        }
                    }
                }
            }
        }
        .confirmationDialog("Reset all settings?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { engine.resetSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your per-app choices and options go back to the defaults. Your history is kept.")
        }
    }

    private var indexText: String {
        let info = engine.indexInfo
        guard info.date != nil else { return "\(engine.installedApps.count) apps (saved index)" }
        return "\(info.appCount) apps in \(String(format: "%.2f", info.seconds)) s" + (ui.advanced ? " · \(info.reused) cached · \(info.read) read" : "")
    }
}
