// Renders the Coremium logo into the app-icon set (and a README image).
//
//   swiftc -parse-as-library -o /tmp/make-icon scripts/make-icon.swift Sources/Coremium/Branding/Logo.swift && /tmp/make-icon
//
// The generated PNGs are committed, so contributors don't need to run this.
import AppKit
import SwiftUI

@main
struct MakeIcon {
    @MainActor
    static func render(_ pixels: Int, asAppIcon: Bool) -> Data? {
        let view = CoremiumLogo(asAppIcon: asAppIcon).frame(width: CGFloat(pixels), height: CGFloat(pixels))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let cg = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    }

    @MainActor
    static func main() {
        _ = NSApplication.shared
        let root = FileManager.default.currentDirectoryPath
        let setDir = "\(root)/Sources/Coremium/Assets.xcassets/AppIcon.appiconset"
        try? FileManager.default.createDirectory(atPath: setDir, withIntermediateDirectories: true)

        // (point size, scale) pairs required for a macOS app icon
        let variants: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
        var images: [[String: String]] = []
        for (points, scale) in variants {
            let pixels = points * scale
            let name = "icon_\(points)x\(points)@\(scale)x.png"
            guard let data = render(pixels, asAppIcon: true) else { print("render failed for \(name)"); exit(1) }
            try! data.write(to: URL(fileURLWithPath: "\(setDir)/\(name)"))
            images.append(["size": "\(points)x\(points)", "idiom": "mac", "filename": name, "scale": "\(scale)x"])
        }
        let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
        let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
        try! json.write(to: URL(fileURLWithPath: "\(setDir)/Contents.json"))
        let catalogInfo = try! JSONSerialization.data(withJSONObject: ["info": ["version": 1, "author": "xcode"]], options: [])
        try! catalogInfo.write(to: URL(fileURLWithPath: "\(root)/Sources/Coremium/Assets.xcassets/Contents.json"))

        try? FileManager.default.createDirectory(atPath: "\(root)/docs/assets", withIntermediateDirectories: true)
        if let data = render(512, asAppIcon: false) {
            try! data.write(to: URL(fileURLWithPath: "\(root)/docs/assets/logo.png"))
        }
        print("Wrote \(images.count) icon sizes and docs/assets/logo.png")
    }
}
