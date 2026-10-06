import CoreGraphics
import XCTest
@testable import CoremiumCore

/// Window frames measured on macOS 27: a 14" MacBook Pro (menu bar 33) and a 1920×1080 display to its right (menu bar 30),
/// with the menu bar shown in fullscreen.
final class FullscreenDetectionTests: XCTestCase {
    let laptop = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let external = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
    let me: Int32 = 99

    private func window(_ pid: Int32, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, layer: Int = 0) -> WindowSnapshot {
        WindowSnapshot(pid: pid, layer: layer, bounds: CGRect(x: x, y: y, width: w, height: h))
    }

    private func covered(_ windows: [WindowSnapshot]) -> Set<Int> {
        FullscreenDetection.coveredDisplays(windows: windows, displays: [laptop, external], ownPID: me)
    }

    func testOrdinaryAndMaximizedWindowsGetNothing() {
        XCTAssertEqual(covered([window(10, 200, 350, 600, 432), window(11, 1712, 448, 600, 432)]), [])
        // Maximized ("Fill") on each display: same frame as fullscreen, but no fullscreen title bar.
        XCTAssertEqual(covered([window(10, 0, 33, 1512, 949), window(11, 1512, 30, 1920, 1050)]), [])
    }

    func testNativeFullscreenWithItsTitleBar() {
        XCTAssertEqual(covered([window(10, 0, 33, 1512, 32), window(10, 0, 33, 1512, 949)]), [0])
        // As listed while the title bar is hidden: alpha 0.
        let hiddenTitleBar = WindowSnapshot(pid: 10, layer: 0, bounds: CGRect(x: 1512, y: 30, width: 1920, height: 32), alpha: 0)
        XCTAssertEqual(covered([hiddenTitleBar, window(10, 1512, 30, 1920, 1050)]), [1])
        XCTAssertEqual(covered([window(11, 1512, 30, 1920, 32), window(11, 1512, 30, 1920, 1050)]), [1])
        // Chrome draws a taller title bar of its own.
        XCTAssertEqual(covered([window(12, 1512, 30, 1920, 149), window(12, 1512, 30, 1920, 1050)]), [1])
    }

    func testTitleBarMustBelongToTheSameApp() {
        XCTAssertEqual(covered([window(10, 0, 33, 1512, 32), window(11, 0, 33, 1512, 949)]), [])
    }

    func testBorderlessFullscreenCoversTheWholeDisplay() {
        XCTAssertEqual(covered([window(10, 0, 0, 1512, 982)]), [0])
        XCTAssertEqual(covered([window(10, 0, 0, 1512, 982), window(11, 1512, 0, 1920, 1080)]), [0, 1])
    }

    func testIgnoresOwnHiddenNonNormalAndPartialWindows() {
        XCTAssertEqual(covered([window(me, 0, 0, 1512, 982)]), [])
        XCTAssertEqual(covered([WindowSnapshot(pid: 10, layer: 0, bounds: laptop, alpha: 0)]), [])
        XCTAssertEqual(covered([window(10, 0, 0, 1512, 982, layer: 3)]), [])
        XCTAssertEqual(covered([window(10, 0, 0, 1512, 900)]), [], "doesn't reach the bottom")
        XCTAssertEqual(covered([window(10, 0, 120, 1512, 40), window(10, 0, 120, 1512, 862)]), [], "starts too low")
    }

    func testParsesWindowServerEntries() {
        let entry: [String: Any] = [
            "kCGWindowOwnerPID": NSNumber(value: 42), "kCGWindowLayer": NSNumber(value: 0), "kCGWindowAlpha": NSNumber(value: 1.0),
            "kCGWindowBounds": ["X": 0, "Y": 33, "Width": 1512, "Height": 949],
        ]
        XCTAssertEqual(FullscreenDetection.snapshots(from: [entry, ["kCGWindowLayer": NSNumber(value: 0)]]),
                       [WindowSnapshot(pid: 42, layer: 0, bounds: CGRect(x: 0, y: 33, width: 1512, height: 949))])
    }
}
