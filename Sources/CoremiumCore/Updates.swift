import Foundation

/// A newer release on GitHub, with the files the in-app updater needs.
public struct ReleaseInfo: Equatable, Sendable {
    public let version: String
    public let notes: String
    public let pageURL: URL
    public let zipURL: URL
    public let checksumURL: URL
}

public enum UpdateCheck {
    public static let latestAPI = URL(string: "https://api.github.com/repos/Cubinghackerz/Coremium/releases/latest")!

    /// "v2.0.1" / "2.0.1" → [2, 0, 1]. Pre-release suffixes ("-beta") are ignored for ordering.
    public static func parts(_ version: String) -> [Int] {
        let core = version.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: "-").first.map(String.init) ?? ""
        return core.split(separator: ".").map { Int($0) ?? 0 }
    }

    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Reads GitHub's "latest release" JSON. Only macOS releases (tags "v…" with a .zip and .sha256) qualify.
    public static func parse(_ data: Data) -> ReleaseInfo? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String, tag.hasPrefix("v"),
              let page = (json["html_url"] as? String).flatMap(URL.init(string:)),
              let assets = json["assets"] as? [[String: Any]] else { return nil }
        func asset(_ suffix: String) -> URL? {
            assets.first { ($0["name"] as? String)?.hasSuffix(suffix) == true && ($0["name"] as? String)?.contains("Windows") == false }
                .flatMap { $0["browser_download_url"] as? String }.flatMap(URL.init(string:))
        }
        guard let zip = asset(".zip"), let sums = asset(".sha256") else { return nil }
        return ReleaseInfo(version: String(tag.dropFirst()), notes: json["body"] as? String ?? "", pageURL: page, zipURL: zip, checksumURL: sums)
    }

    /// The expected SHA-256 for `fileName` from a `shasum -a 256` style file.
    public static func checksum(for fileName: String, in sums: String) -> String? {
        for line in sums.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            if fields.count >= 2, fields.last.map(String.init) == fileName { return String(fields[0]).lowercased() }
        }
        return nil
    }
}
