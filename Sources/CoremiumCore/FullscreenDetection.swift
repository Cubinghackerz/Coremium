import CoreGraphics
import Foundation

/// One on-screen window, as the window server reports it (bounds in global top-left coordinates).
public struct WindowSnapshot: Equatable {
    public var pid: Int32
    public var layer: Int
    public var bounds: CGRect
    public var alpha: Double

    public init(pid: Int32, layer: Int, bounds: CGRect, alpha: Double = 1) {
        self.pid = pid
        self.layer = layer
        self.bounds = bounds
        self.alpha = alpha
    }
}

/// One display: global top-left bounds.
public typealias DisplayBounds = CGRect

/// Decides which displays are showing a fullscreen app, so the fullscreen fix only exists where it can matter.
/// Direct-to-Display (the cause of the stutter) only happens for a fullscreen window. On every other display
/// Coremium adds nothing, and windows move, tile and resize exactly as stock macOS.
///
/// Measured on macOS 27: with the menu bar shown in fullscreen, a fullscreen window has exactly the frame of a
/// maximized one (below the menu bar, down to the bottom edge), and the menu bar window stays listed. What tells them
/// apart is the title bar AppKit keeps for a fullscreen window: a second, short window of the same app at the same
/// top-left corner and width. Borderless fullscreen games instead cover the whole display, menu bar area included,
/// which no ordinary window does.
public enum FullscreenDetection {
    /// Indexes into `displays` showing a fullscreen window of another app.
    public static func coveredDisplays(windows: [WindowSnapshot], displays: [DisplayBounds], ownPID: Int32) -> Set<Int> {
        let layerZero = windows.filter { $0.layer == 0 && $0.pid != ownPID }
        let normal = layerZero.filter { $0.alpha > 0 }
        var covered = Set<Int>()
        for (index, display) in displays.enumerated() {
            for window in normal where spansWidthToBottom(window.bounds, display) {
                let top = window.bounds.minY - display.minY
                let edgeToEdge = abs(top) <= 1
                // The title bar is transparent until the pointer reaches the top edge, so its alpha doesn't matter.
                let hasFullscreenTitleBar = layerZero.contains { other in
                    other.pid == window.pid && other.bounds.height < window.bounds.height
                        && abs(other.bounds.minX - window.bounds.minX) <= 1 && abs(other.bounds.minY - window.bounds.minY) <= 1
                        && abs(other.bounds.width - window.bounds.width) <= 1
                }
                // A fullscreen window starts at the top edge, below the notch, or below a shown menu bar.
                if edgeToEdge || (top <= maxTopGap && hasFullscreenTitleBar) {
                    covered.insert(index)
                    break
                }
            }
        }
        return covered
    }

    /// Notch insets and menu bars are 24–44 points; a fullscreen window never starts lower than this.
    static let maxTopGap: CGFloat = 50

    static func spansWidthToBottom(_ window: CGRect, _ display: CGRect) -> Bool {
        abs(window.minX - display.minX) <= 1 && abs(window.width - display.width) <= 1 && abs(window.maxY - display.maxY) <= 1
            && window.minY >= display.minY - 1
    }

    /// Parses `CGWindowListCopyWindowInfo` entries. Reads only owner pid, layer, bounds and alpha, which need no
    /// Screen Recording permission.
    public static func snapshots(from info: [[String: Any]]) -> [WindowSnapshot] {
        info.compactMap { entry in
            guard let pid = (entry["kCGWindowOwnerPID"] as? NSNumber)?.int32Value,
                  let layer = (entry["kCGWindowLayer"] as? NSNumber)?.intValue,
                  let raw = entry["kCGWindowBounds"] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: raw as CFDictionary) else { return nil }
            let alpha = (entry["kCGWindowAlpha"] as? NSNumber)?.doubleValue ?? 1
            return WindowSnapshot(pid: pid, layer: layer, bounds: bounds, alpha: alpha)
        }
    }
}
