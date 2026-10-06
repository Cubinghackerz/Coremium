import CoremiumCore
import SwiftUI

/// The one-line promise, used everywhere.
enum Pitch {
    static let headline = "Keep what matters smooth, without closing anything."
    static let subline = "Coremium protects the app you're using and quietly moves everything else to your Mac's efficiency cores. Games, renders, builds and local AI stay responsive while your other apps keep running."
}

extension AppRule {
    /// One sentence a newcomer can understand.
    var meaning: String {
        switch self {
        case .boost: return "Protected. When you use it (or it's busy), everything else is kept out of its way."
        case .normal: return "Left alone. Coremium never touches it."
        case .auto: return "Steps aside: moves to the efficiency cores while something else is boosted."
        case .efficiency: return "Always on the efficiency cores, unless you're using it."
        }
    }

    var example: String {
        switch self {
        case .boost: return "Your game, Final Cut, Xcode, LM Studio."
        case .normal: return "Finder, a PDF you're reading."
        case .auto: return "Chrome, Slack, a chat app while you play."
        case .efficiency: return "A sync or backup app you never need fast."
        }
    }
}

/// Why it is safe, stated plainly.
struct TrustCard: View {
    var compact = false

    private let items: [(String, String, String)] = [
        ("arrow.uturn.backward.circle.fill", "Fully reversible", "Undone when you quit, and again at the next start if the app ever crashes."),
        ("xmark.circle.fill", "Never closes or kills anything", "Apps keep running; they just use the efficient cores while you're busy elsewhere."),
        ("gearshape.2.fill", "Uses macOS's own scheduling", "The same built-in priority control as the taskpolicy tool. No hacks, no drivers, no admin password."),
        ("lock.shield.fill", "Private", "No accounts, no network access. Settings and history stay on this Mac."),
        ("chevron.left.forwardslash.chevron.right", "Open source", "MIT licensed. Read exactly what it does."),
    ]

    var body: some View {
        Card(padding: compact ? 12 : 16) {
            VStack(alignment: .leading, spacing: compact ? 6 : 9) {
                SectionLabel(text: "Safe by design")
                ForEach(items, id: \.1) { item in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: item.0).font(.system(size: 12)).foregroundColor(Theme.accent).frame(width: 18)
                        if compact {
                            Text(item.1).font(.system(size: 11.5, weight: .semibold, design: .rounded)).foregroundColor(.white)
                            Spacer(minLength: 0)
                        } else {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.1).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.white)
                                Text(item.2).font(.system(size: 11, design: .rounded)).foregroundColor(Theme.textDim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// What the four choices mean.
struct RuleLegend: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10, alignment: .top), GridItem(.flexible(), spacing: 10, alignment: .top)],
                  alignment: .leading, spacing: 8) {
            ForEach(AppRule.allCases, id: \.self) { rule in
                HStack(alignment: .top, spacing: 7) {
                    Circle().fill(rule.tint).frame(width: 7, height: 7).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(rule.shortLabel).font(.system(size: 11.5, weight: .bold, design: .rounded)).foregroundColor(rule.tint)
                        Text(rule.meaning).font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
