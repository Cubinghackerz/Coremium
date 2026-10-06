import CoremiumCore
import SwiftUI

/// Shows real activity immediately; the full explanation is optional.
struct OnboardingView: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var ui: NotchUIState
    var onFinish: () -> Void

    private var notable: [AppRow] {
        Array(engine.rows.filter { [.game, .creative, .developer, .localAI].contains($0.category) }.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                CoremiumLogo().frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(engine.paused ? "Coremium is paused" : "Coremium is running in \(engine.rules.mode.label) mode")
                        .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Text("\(Pitch.subline)").font(.system(size: 12, design: .rounded)).foregroundColor(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Card(padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "On your Mac right now")
                    Text(engine.statusLine).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let decision = engine.latestDecision, !engine.paused {
                        Text(decision.detail).font(.system(size: 11.5, design: .rounded)).foregroundColor(Theme.textDim)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                    if !notable.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(notable) { row in
                                HStack(spacing: 5) {
                                    AppIconView(path: row.path)
                                    Text(row.name).font(.system(size: 11, design: .rounded)).foregroundColor(.white.opacity(0.85))
                                        .lineLimit(1)
                                }
                            }
                        }
                        .accessibilityLabel("Detected running apps")
                    }
                }
            }
            Text("Helps when background CPU work competes with your app. On a quiet Mac, there may be nothing to change.")
                .font(.system(size: 11.5, design: .rounded)).foregroundColor(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
            SettingRow(title: "Open at login", detail: "Optional. Keep Automatic ready when you start your Mac.",
                       isOn: Binding(get: { engine.launchAtLogin }, set: { engine.setLaunchAtLogin($0) }))
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button("How it works") {
                    ui.showingOnboarding = false
                    ui.showingTour = true
                }.buttonStyle(GhostButtonStyle())
                Button("See a simulation") { ui.finishOnboarding(tab: .simulate) }.buttonStyle(GhostButtonStyle())
                Spacer(minLength: 0)
                Button("Continue to live view", action: onFinish).buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
            Text(ui.geometry.hasNotch ? "Hover the notch or use the menu-bar chip to reopen. Click elsewhere or press Escape to close."
                 : "Use the menu-bar chip to reopen. Click elsewhere or press Escape to close.")
                .font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim)
        }
        .padding(.horizontal, 30).padding(.top, 12).padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The optional welcome tour, available from the first screen, Settings, and the menu bar.
struct WelcomeTourView: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var ui: NotchUIState
    var onFinish: () -> Void

    @State private var step: Int
    private let lastStep = 5

    init(engine: AppEngine, ui: NotchUIState, initialStep: Int = 0, onFinish: @escaping () -> Void) {
        self.engine = engine
        self.ui = ui
        self.onFinish = onFinish
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch step {
                case 0: Welcome()
                case 1: HowItWorks()
                case 2: FourChoices()
                case 3: PickMode(engine: engine)
                case 4: YourApps(engine: engine)
                default: AllSet(engine: engine, ui: ui)
                }
            }
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .frame(maxWidth: 640, maxHeight: .infinity)
            .padding(.horizontal, 24)
            footer
        }
        .padding(.bottom, 18).padding(.top, 6)
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: step)
    }

    private var footer: some View {
        HStack {
            Button("Back") { step -= 1 }.buttonStyle(GhostButtonStyle()).opacity(step == 0 ? 0 : 1).disabled(step == 0)
            Spacer()
            HStack(spacing: 6) {
                ForEach(0...lastStep, id: \.self) { index in
                    Capsule().fill(index == step ? Theme.accent : Color.white.opacity(0.2)).frame(width: index == step ? 20 : 6, height: 6)
                }
            }
            Spacer()
            Button("Skip") { onFinish() }.buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .medium, design: .rounded)).foregroundColor(Theme.textDim).opacity(step == lastStep ? 0 : 1)
            Button(step == lastStep ? "Start using Coremium" : "Continue") {
                if step == lastStep { onFinish() } else { step += 1 }
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 30)
    }
}

private struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.white).multilineTextAlignment(.center)
            Text(subtitle).font(.system(size: 12.5, design: .rounded)).foregroundColor(Theme.textDim)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).frame(maxWidth: 520)
        }
    }
}

private struct Welcome: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            CoremiumLogo().frame(width: 92, height: 92).shadow(color: Theme.accent.opacity(0.45), radius: 22)
            Text("Welcome to Coremium").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(Pitch.headline).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(Theme.accent)
                .multilineTextAlignment(.center)
            Text(Pitch.subline).font(.system(size: 12.5, design: .rounded)).foregroundColor(Theme.textDim)
                .multilineTextAlignment(.center).frame(maxWidth: 520).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct HowItWorks: View {
    @State private var moved = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            StepHeader(title: "Make room for what you're doing", subtitle: "Coremium lowers eligible background apps' priority while your game or work app stays at normal priority. On Apple Silicon, macOS schedules that background work on efficiency cores.")
            HStack(spacing: 14) {
                zone("Performance cores", "Fast, power-hungry", Theme.yield,
                     moved ? [("gamecontroller.fill", "Game")] : [("gamecontroller.fill", "Game"), ("globe", "Browser"), ("bubble.left.fill", "Chat"), ("sparkles", "AI")])
                Image(systemName: "arrow.right").font(.system(size: 18, weight: .bold)).foregroundColor(Theme.textDim)
                zone("Efficiency cores", "Calm, frugal", Theme.eco,
                     moved ? [("globe", "Browser"), ("bubble.left.fill", "Chat"), ("sparkles", "AI")] : [])
            }
            Text(moved ? "Illustration: eligible background apps have lower priority." : "Illustration: busy apps can compete for CPU time.")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded)).foregroundColor(moved ? Theme.good : Theme.warn)
            Spacer(minLength: 0)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) { moved = true } }
        }
    }

    private func zone(_ title: String, _ subtitle: String, _ tint: Color, _ apps: [(String, String)]) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(tint)
            Text(subtitle).font(.system(size: 10, design: .rounded)).foregroundColor(Theme.textDim)
            VStack(spacing: 5) {
                ForEach(apps, id: \.1) { app in
                    HStack(spacing: 5) {
                        Image(systemName: app.0).font(.system(size: 10))
                        Text(app.1).font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(tint.opacity(0.22)))
                    .transition(.scale.combined(with: .opacity))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .padding(12).frame(width: 220, height: 150, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(tint.opacity(0.45), lineWidth: 1.2))
    }
}

private struct FourChoices: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            StepHeader(title: "Four simple choices per app", subtitle: "Coremium picks sensible defaults. Change any app whenever you like.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(AppRule.allCases, id: \.self) { rule in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.shortLabel).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(rule.tint)
                        Text(rule.meaning).font(.system(size: 11.5, design: .rounded)).foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("e.g. " + rule.example).font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12).frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(rule.tint.opacity(0.4), lineWidth: 1))
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct PickMode: View {
    @ObservedObject var engine: AppEngine

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            StepHeader(title: "Pick a mode", subtitle: "A mode decides who gets protected. Automatic watches what you're doing and switches for you; most people never need to change it.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(PerformanceMode.allCases, id: \.self) { mode in
                    let selected = engine.rules.mode == mode
                    Button { engine.rules.mode = mode } label: {
                        VStack(spacing: 5) {
                            Image(systemName: mode.symbol).font(.system(size: 16, weight: .semibold)).foregroundColor(selected ? .black : mode.tint)
                            Text(mode.label).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(selected ? .black : .white)
                            if mode == .automatic { Tag(text: "Recommended", color: selected ? .black : Theme.accent) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 66)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? mode.tint : Color.white.opacity(0.06)))
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(engine.rules.mode.summary).font(.system(size: 12, design: .rounded)).foregroundColor(Theme.textDim)
                .multilineTextAlignment(.center).frame(maxWidth: 500, minHeight: 34).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct YourApps: View {
    @ObservedObject var engine: AppEngine

    private var notable: [InstalledApp] {
        engine.installedApps.filter { [.game, .creative, .localAI, .developer].contains($0.category) }.prefix(10).map { $0 }
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            StepHeader(title: "Here's what we found on your Mac", subtitle: "Coremium recognises apps by kind, so you don't set them up one by one. Fine-tune any of them later in Apps.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach([AppCategory.game, .creative, .developer, .localAI, .browser, .communication], id: \.self) { category in
                    HStack(spacing: 8) {
                        Image(systemName: category.symbol).foregroundColor(category.tint).frame(width: 18)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(engine.installedApps.filter { $0.category == category }.count)")
                                .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(.white)
                            Text(category.label).font(.system(size: 10, design: .rounded)).foregroundColor(Theme.textDim).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card))
                }
            }
            HStack(spacing: 6) { ForEach(notable) { AppIconView(path: $0.path).help($0.name) } }
            if engine.isIndexing { ProgressView().controlSize(.small) }
            Spacer(minLength: 0)
        }
    }
}

private struct AllSet: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var ui: NotchUIState

    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            StepHeader(title: "You're all set", subtitle: "Hover the notch to open this panel any time. Coremium steps in when a game or pro app is in front, and returns everything to normal when you're done.")
            TrustCard(compact: true).frame(maxWidth: 480)
            Card(padding: 10) {
                VStack(spacing: 10) {
                    SettingRow(title: "Open at login", detail: nil,
                               isOn: Binding(get: { engine.launchAtLogin }, set: { engine.setLaunchAtLogin($0) }))
                    SettingRow(title: "Fullscreen fix", detail: FullscreenFix.isRecommended ? "Your Mac runs macOS 27, where fullscreen games can stutter." : nil,
                               badge: FullscreenFix.isRecommended ? "Recommended" : nil, isOn: $engine.rules.fullscreenFixEnabled)
                }
            }
            .frame(maxWidth: 480)
            Spacer(minLength: 0)
        }
    }
}
