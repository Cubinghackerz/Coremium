import SwiftUI

/// The Coremium mark: a chip whose core is split into a bright performance half and a cool efficiency half.
/// One drawing is used everywhere (app icon, sidebar, onboarding), so it always matches.
struct CoremiumLogo: View {
    /// `true` draws the macOS app-icon shape with the standard transparent margin; `false` fills its frame.
    var asAppIcon = false

    static let cyan = Color(red: 0.36, green: 0.91, blue: 1.0)
    static let blue = Color(red: 0.30, green: 0.55, blue: 1.0)
    static let violet = Color(red: 0.62, green: 0.42, blue: 1.0)
    static let indigo = Color(red: 0.28, green: 0.22, blue: 0.62)

    var body: some View {
        GeometryReader { proxy in
            let canvas = min(proxy.size.width, proxy.size.height)
            // App icons keep ~10% transparent margin around the rounded square.
            let s = asAppIcon ? canvas * 0.8047 : canvas
            ZStack {
                Mark(size: s)
                    .frame(width: s, height: s)
                    .shadow(color: asAppIcon ? Color.black.opacity(0.35) : .clear, radius: canvas * 0.02, y: canvas * 0.012)
            }
            .frame(width: canvas, height: canvas)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Coremium logo")
    }

    private struct Mark: View {
        let size: CGFloat

        var body: some View {
            let corner = size * 0.2237
            let chip = size * 0.50
            let core = size * 0.27
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.16), Color(red: 0.13, green: 0.07, blue: 0.30)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(RadialGradient(colors: [CoremiumLogo.blue.opacity(0.35), .clear],
                                         center: UnitPoint(x: 0.3, y: 0.2), startRadius: 0, endRadius: size * 0.7))
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.04)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: max(1, size * 0.006))

                // Pins
                Pins(chipSize: chip, canvas: size)

                // Chip body
                RoundedRectangle(cornerRadius: chip * 0.22, style: .continuous)
                    .fill(Color.black.opacity(0.45))
                    .frame(width: chip, height: chip)
                RoundedRectangle(cornerRadius: chip * 0.22, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [CoremiumLogo.cyan, CoremiumLogo.violet],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                                  lineWidth: max(1.5, size * 0.02))
                    .frame(width: chip, height: chip)

                // Split core: performance (bright) over efficiency (cool)
                SplitCore(size: core)
                    .frame(width: core, height: core)
            }
        }
    }

    private struct Pins: View {
        let chipSize: CGFloat
        let canvas: CGFloat

        var body: some View {
            let length = canvas * 0.065
            let thickness = max(1.5, canvas * 0.02)
            let spread = chipSize * 0.58
            let offset = chipSize / 2 + length / 2 - canvas * 0.004
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let t = (CGFloat(i) - 1) * spread / 2
                    pin(width: thickness, height: length).offset(x: t, y: -offset)
                    pin(width: thickness, height: length).offset(x: t, y: offset)
                    pin(width: length, height: thickness).offset(x: -offset, y: t)
                    pin(width: length, height: thickness).offset(x: offset, y: t)
                }
            }
        }

        private func pin(width: CGFloat, height: CGFloat) -> some View {
            RoundedRectangle(cornerRadius: min(width, height) / 2, style: .continuous)
                .fill(LinearGradient(colors: [CoremiumLogo.cyan.opacity(0.85), CoremiumLogo.violet.opacity(0.85)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: width, height: height)
        }
    }

    private struct SplitCore: View {
        let size: CGFloat

        var body: some View {
            ZStack {
                // Performance half: upper-left triangle
                Triangle(upperLeft: true)
                    .fill(LinearGradient(colors: [Color.white, CoremiumLogo.cyan, CoremiumLogo.blue],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: CoremiumLogo.cyan.opacity(0.9), radius: size * 0.16)
                // Efficiency half: lower-right triangle
                Triangle(upperLeft: false)
                    .fill(LinearGradient(colors: [CoremiumLogo.violet, CoremiumLogo.indigo],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: max(0.5, size * 0.03))
            )
        }
    }

    private struct Triangle: Shape {
        let upperLeft: Bool

        func path(in rect: CGRect) -> Path {
            var path = Path()
            if upperLeft {
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            } else {
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            }
            path.closeSubpath()
            return path
        }
    }
}

/// Logo plus the product name, used in the sidebar and onboarding.
struct CoremiumWordmark: View {
    var logoSize: CGFloat = 34

    var body: some View {
        HStack(spacing: 10) {
            CoremiumLogo().frame(width: logoSize, height: logoSize)
            Text("Coremium")
                .font(.system(size: logoSize * 0.5, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.75)], startPoint: .top, endPoint: .bottom))
        }
    }
}
