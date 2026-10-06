import XCTest
@testable import CoremiumCore

final class UpdateTests: XCTestCase {
    func testVersionOrdering() {
        XCTAssertTrue(UpdateCheck.isNewer("v2.0.0", than: "0.1.2"))
        XCTAssertTrue(UpdateCheck.isNewer("0.1.10", than: "0.1.9"))
        XCTAssertFalse(UpdateCheck.isNewer("v0.1.2", than: "0.1.2"))
        XCTAssertFalse(UpdateCheck.isNewer("0.1.1", than: "0.1.2"))
        XCTAssertTrue(UpdateCheck.isNewer("2.0", than: "1.9.9"))
    }

    func testParsesMacReleaseAndIgnoresWindowsAssets() throws {
        let json = """
        {"tag_name":"v2.0.0","html_url":"https://github.com/x/y/releases/tag/v2.0.0","body":"Notes",
         "assets":[{"name":"Coremium-Windows-2.0.0-x64.zip","browser_download_url":"https://e/w.zip"},
                   {"name":"Coremium-2.0.0.zip","browser_download_url":"https://e/m.zip"},
                   {"name":"Coremium-2.0.0.sha256","browser_download_url":"https://e/m.sha256"}]}
        """
        let info = try XCTUnwrap(UpdateCheck.parse(Data(json.utf8)))
        XCTAssertEqual(info.version, "2.0.0")
        XCTAssertEqual(info.zipURL.absoluteString, "https://e/m.zip")
        XCTAssertNil(UpdateCheck.parse(Data(#"{"tag_name":"windows-v1","assets":[]}"#.utf8)))
    }

    func testChecksumLookup() {
        let sums = "abc123  Coremium-2.0.0.zip\ndef456  Coremium-2.0.0.dmg\n"
        XCTAssertEqual(UpdateCheck.checksum(for: "Coremium-2.0.0.zip", in: sums), "abc123")
        XCTAssertNil(UpdateCheck.checksum(for: "other.zip", in: sums))
    }
}
