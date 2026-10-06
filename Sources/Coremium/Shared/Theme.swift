import CoremiumCore
import SwiftUI

enum Theme {
    static let background = Color(red: 0.04, green: 0.045, blue: 0.08)
    static let card = Color.white.opacity(0.055)
    static let border = Color.white.opacity(0.09)
    static let textDim = Color.white.opacity(0.55)
    /// Monochrome: white is the only accent. One muted amber is kept for warnings, because a warning must stand out.
    static let accent = Color.white
    static let warn = Color(red: 0.93, green: 0.78, blue: 0.52)
}

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .bold, design: .rounded)).tracking(0.8)
            .foregroundColor(Theme.textDim)
    }
}

/// Lets screenshots/previews render scrolling areas flat (ImageRenderer can't draw scroll views).
private struct FlatRenderKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var renderFlat: Bool {
        get { self[FlatRenderKey.self] }
        set { self[FlatRenderKey.self] = newValue }
    }
}

/// A vertical scroll area that hides its scroller.
struct FlexScroll<Content: View>: View {
    @Environment(\.renderFlat) private var flat
    @ViewBuilder var content: Content

    var body: some View {
        if flat {
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                content.frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}

/// A small coloured tag.
struct Tag: View {
    let text: String
    var color: Color = Theme.accent
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .lineLimit(1).fixedSize()
            .padding(.horizontal, 7).padding(.vertical, 3)
            .foregroundColor(color)
            .background(Capsule().fill(color.opacity(0.18)))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 18).padding(.vertical, 9)
            .background(Capsule().fill(tint))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.08)))
    }
}

/// A labelled on/off row used by Settings.
struct SettingRow: View {
    let title: String
    let detail: String?
    var badge: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.white)
                    if let badge { Tag(text: badge) }
                }
                if let detail {
                    Text(detail).font(.system(size: 11.5, design: .rounded)).foregroundColor(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).tint(Color(white: 0.85))
        }
    }
}

extension AppCategory {
    var tint: Color { Color(white: 0.72) }
}
