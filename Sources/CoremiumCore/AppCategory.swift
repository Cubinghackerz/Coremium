import Foundation

/// What kind of app something is. Performance modes decide what to boost or demote by category.
public enum AppCategory: String, Codable, CaseIterable, Sendable {
    case game, creative, developer, localAI, browser, communication, ai, media, productivity, system, other

    public var label: String {
        switch self {
        case .game: return "Games"
        case .creative: return "Creative tools"
        case .localAI: return "Local AI & compute"
        case .developer: return "Developer tools"
        case .browser: return "Browsers"
        case .communication: return "Communication"
        case .ai: return "AI assistants"
        case .media: return "Media"
        case .productivity: return "Productivity"
        case .system: return "System & utilities"
        case .other: return "Other"
        }
    }

    public var symbol: String {
        switch self {
        case .game: return "gamecontroller.fill"
        case .creative: return "paintpalette.fill"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .localAI: return "brain.head.profile"
        case .browser: return "globe"
        case .communication: return "bubble.left.and.bubble.right.fill"
        case .ai: return "sparkles"
        case .media: return "music.note"
        case .productivity: return "doc.text.fill"
        case .system: return "gearshape.fill"
        case .other: return "app.fill"
        }
    }
}

/// Decides an app's category from its bundle identifier, falling back to the category the developer declared
/// in Info.plist (`LSApplicationCategoryType`).
public enum AppClassifier {
    static let exact: [String: AppCategory] = [
        // Games and game launchers
        "com.roblox.RobloxPlayer": .game, "com.modrinth.theseus": .game, "com.mojang.minecraftlauncher": .game,
        "com.mojang.minecraft": .game, "net.minecraft.launcher": .game, "com.moonsworth.client": .game,
        // Pro creative
        "com.apple.FinalCut": .creative, "com.apple.logic10": .creative, "com.apple.motionapp": .creative,
        "com.apple.Compressor": .creative, "com.apple.garageband10": .creative, "com.apple.iMovieApp": .creative,
        "com.pixelmatorteam.pixelmator.x": .creative, "com.figma.Desktop": .creative,
        "com.bohemiancoding.sketch3": .creative, "org.blenderfoundation.blender": .creative,
        "com.ableton.live": .creative, "com.obsproject.obs-studio": .creative,
        "com.apple.Photos": .media, "com.apple.Preview": .productivity,
        // Local AI, image generation, virtual machines (heavy sustained compute)
        "com.electron.ollama": .localAI, "ai.elementlabs.lmstudio": .localAI, "com.liuliu.draw-things": .localAI,
        "com.parallels.desktop.console": .localAI, "com.utmapp.UTM": .localAI, "dev.kdrag0n.MacVirt": .localAI,
        "com.vmware.fusion": .localAI,
        // Developer tools
        "com.apple.dt.Xcode": .developer, "com.apple.Terminal": .developer, "com.googlecode.iterm2": .developer,
        "dev.warp.Warp-Stable": .developer, "com.microsoft.VSCode": .developer, "com.todesktop.230313mzl4w4u92": .developer, // Cursor
        "com.google.antigravity": .developer, "com.google.antigravity-ide": .developer,
        "com.exafunction.windsurf": .developer,   // Devin / Windsurf
        "dev.kiro.desktop": .developer, "ai.opencode.desktop": .developer, "com.github.GitHubClient": .developer,
        "com.Roblox.RobloxStudio": .developer, "com.sublimetext.4": .developer, "com.google.android.studio": .developer,
        "com.docker.docker": .developer, "com.postmanlabs.mac": .developer,
        // Browsers
        "com.google.Chrome": .browser, "org.mozilla.firefox": .browser, "com.apple.Safari": .browser,
        "com.brave.Browser": .browser, "com.microsoft.edgemac": .browser, "company.thebrowser.Browser": .browser,
        "com.operasoftware.Opera": .browser, "com.vivaldi.Vivaldi": .browser, "ai.perplexity.comet": .browser,
        // Communication
        "com.hnc.Discord": .communication, "com.tinyspeck.slackmacgap": .communication, "us.zoom.xos": .communication,
        "com.microsoft.teams2": .communication, "com.apple.MobileSMS": .communication,
        "net.whatsapp.WhatsApp": .communication, "ru.keepcoder.Telegram": .communication,
        "com.apple.FaceTime": .communication, "com.apple.mail": .communication,
        // AI assistants
        "com.anthropic.claudefordesktop": .ai, "com.openai.codex": .ai, "com.openai.chat": .ai,
        // Media
        "com.spotify.client": .media, "com.apple.Music": .media, "com.apple.TV": .media, "org.videolan.vlc": .media,
        // Productivity
        "com.microsoft.Word": .productivity, "com.microsoft.Excel": .productivity,
        "com.microsoft.Powerpoint": .productivity, "com.apple.iWork.Pages": .productivity,
        "com.apple.iWork.Numbers": .productivity, "com.apple.iWork.Keynote": .productivity,
        "notion.id": .productivity, "md.obsidian": .productivity,
        // System-ish and background heavy things
        "com.apple.finder": .system, "com.apple.dock": .system, "com.apple.systempreferences": .system,
        "com.apple.ActivityMonitor": .system, "com.apple.campo": .system,   // Siri AI
        "com.valvesoftware.steam": .other,
    ]

    /// Checked in order; the first matching prefix wins, so specific entries must come before general ones.
    static let prefixes: [(String, AppCategory)] = [
        ("com.adobe.acc", .system), ("com.adobe.CCXProcess", .system), ("com.adobe.AdobeCreativeCloud", .system),
        ("com.adobe.Acrobat", .productivity), ("com.adobe.Reader", .productivity),
        ("com.adobe.", .creative),
        ("com.jetbrains.", .developer), ("com.unity3d.", .developer), ("com.epicgames.UE", .developer),
        ("com.autodesk.", .creative), ("com.blackmagic-design.", .creative), ("net.maxon.", .creative),
        ("com.seriflabs.", .creative), ("com.maxon.", .creative), ("com.apple.logic", .creative),
        ("com.microsoft.VSCode", .developer),
        ("com.parallels.", .localAI), ("com.vmware.", .localAI),
    ]

    /// Names of local-AI tools, matched against the app name when the bundle identifier isn't known.
    static let localAINames = ["ollama", "lm studio", "lmstudio", "comfyui", "draw things", "diffusionbee", "invokeai",
                               "gpt4all", "msty", "stable diffusion", "automatic1111"]

    public static func classify(bundleID: String?, lsCategory: String?, path: String? = nil, name: String? = nil) -> AppCategory {
        if let id = bundleID {
            if let hit = exact[id] { return hit }
            for (prefix, category) in prefixes where id.hasPrefix(prefix) { return category }
        }
        if let lowered = name?.lowercased(), localAINames.contains(where: { lowered.contains($0) }) { return .localAI }
        // Anything installed inside a Steam library is a game.
        if let path, path.contains("/steamapps/common/") { return .game }
        return fromAppStoreCategory(lsCategory)
    }

    static func fromAppStoreCategory(_ value: String?) -> AppCategory {
        guard let value = value?.lowercased() else { return .other }
        if value.contains("games") { return .game }
        switch value {
        case "public.app-category.developer-tools": return .developer
        case "public.app-category.graphics-design", "public.app-category.photography", "public.app-category.video",
             "public.app-category.music": return .creative
        case "public.app-category.social-networking": return .communication
        case "public.app-category.productivity", "public.app-category.business", "public.app-category.finance",
             "public.app-category.education", "public.app-category.reference": return .productivity
        case "public.app-category.entertainment": return .media
        case "public.app-category.utilities": return .system
        default: return .other
        }
    }
}

/// How aggressively Coremium protects what you're doing.
public enum PerformanceMode: String, Codable, CaseIterable, Sendable {
    /// Picks Gaming, Professional or Coding by itself, based on what you're using.
    case automatic
    /// Does nothing on its own. Only your per-app rules apply.
    case balanced
    case gaming
    case professional
    case coding
    case localAI

    public var label: String {
        switch self {
        case .automatic: return "Automatic"
        case .balanced: return "Balanced"
        case .gaming: return "Gaming"
        case .professional: return "Creator"
        case .coding: return "Coding"
        case .localAI: return "Local AI"
        }
    }

    public var symbol: String {
        switch self {
        case .automatic: return "wand.and.stars"
        case .balanced: return "scalemass"
        case .gaming: return "gamecontroller.fill"
        case .professional: return "paintpalette.fill"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .localAI: return "brain.head.profile"
        }
    }

    public var summary: String {
        switch self {
        case .automatic: return "Watches what you're doing and switches between Gaming, Creator, Coding and Local AI for you."
        case .balanced: return "No automatic changes. Only the choices you make per app apply."
        case .gaming: return "Games get the performance cores. Browsers, dev tools, chat and AI apps move to efficiency cores."
        case .professional: return "Video, audio, 3D, design and photo apps get the performance cores. Games, browsers, chat and AI assistants move aside."
        case .coding: return "Editors, terminals and builds get the performance cores. Games and creative apps move aside."
        case .localAI: return "LLMs, image generation, containers and VMs get the performance cores. Games, browsers, chat and creative apps move aside."
        }
    }
}

/// Which categories a mode protects (boost) and which it pushes to the efficiency cores while a session runs (demote).
public struct ModeProfile: Equatable, Sendable {
    public let mode: PerformanceMode
    public let boost: Set<AppCategory>
    public let demote: Set<AppCategory>

    public static let balanced = ModeProfile(mode: .balanced, boost: [], demote: [])
    public static let gaming = ModeProfile(mode: .gaming, boost: [.game],
                                           demote: [.creative, .developer, .browser, .communication, .ai])
    public static let professional = ModeProfile(mode: .professional, boost: [.creative],
                                                 demote: [.game, .browser, .communication, .ai])
    public static let coding = ModeProfile(mode: .coding, boost: [.developer], demote: [.game, .creative])
    public static let localAI = ModeProfile(mode: .localAI, boost: [.localAI],
                                            demote: [.game, .creative, .browser, .communication])

    /// The profile that is in force right now. `.automatic` follows the app in front, or a busy game/pro/dev app.
    public static func resolve(mode: PerformanceMode, frontCategory: AppCategory?,
                               busyCategories: Set<AppCategory>) -> ModeProfile {
        switch mode {
        case .balanced: return .balanced
        case .gaming: return .gaming
        case .professional: return .professional
        case .coding: return .coding
        case .localAI: return .localAI
        case .automatic:
            if let front = frontCategory, let profile = trigger(front) { return profile }
            for category in [AppCategory.game, .localAI, .creative, .developer] where busyCategories.contains(category) {
                if let profile = trigger(category) { return profile }
            }
            return .balanced
        }
    }

    private static func trigger(_ category: AppCategory) -> ModeProfile? {
        switch category {
        case .game: return .gaming
        case .creative: return .professional
        case .developer: return .coding
        case .localAI: return .localAI
        default: return nil
        }
    }
}

/// An app found on disk.
public struct InstalledApp: Identifiable, Hashable, Sendable, Codable {
    public var id: String { bundleID }
    public let name: String
    public let bundleID: String
    public let path: String
    public let category: AppCategory

    public init(name: String, bundleID: String, path: String, category: AppCategory) {
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.category = category
    }
}

/// A folder to search for apps, and how many levels of subfolders to look in (1 = e.g. "Adobe Photoshop 2025/").
public struct ScanRoot: Hashable, Sendable {
    public let url: URL
    public let depth: Int

    public init(_ url: URL, depth: Int = 1) {
        self.url = url
        self.depth = depth
    }
}

/// Remembers what was found last time, so the next launch shows results instantly and only re-reads changed apps.
public struct AppIndexCache: Codable, Sendable {
    public struct Entry: Codable, Sendable {
        public var modified: TimeInterval
        public var app: InstalledApp
    }

    public var entries: [String: Entry] = [:]
    public init() {}

    public static func load(from url: URL) -> AppIndexCache {
        guard let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(AppIndexCache.self, from: data) else { return AppIndexCache() }
        return cache
    }

    public func save(to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) { try? data.write(to: url, options: .atomic) }
    }

    /// Apps in the cache, in a stable order, for showing something immediately at launch.
    public var apps: [InstalledApp] {
        entries.values.map(\.app).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

public struct ScanReport: Sendable {
    public let apps: [InstalledApp]
    public let seconds: Double
    /// Apps taken from the cache without reading their Info.plist again.
    public let reused: Int
    public let read: Int
}

public enum InstalledAppScanner {
    public static var defaultRoots: [ScanRoot] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ScanRoot(URL(fileURLWithPath: "/Applications")),
            ScanRoot(URL(fileURLWithPath: "/Applications/Utilities"), depth: 0),
            ScanRoot(URL(fileURLWithPath: "/System/Applications"), depth: 0),
            ScanRoot(URL(fileURLWithPath: "/System/Applications/Utilities"), depth: 0),
            ScanRoot(home.appendingPathComponent("Applications")),
            ScanRoot(URL(fileURLWithPath: "/Applications/Setapp")),
            // Steam games on macOS: steamapps/common/<Game>/<Game>.app
            ScanRoot(home.appendingPathComponent("Library/Application Support/Steam/steamapps/common"), depth: 2),
        ]
    }

    /// Folders worth watching for installs and removals.
    public static var watchedFolders: [URL] {
        defaultRoots.map(\.url).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Simple scan (no cache). Only reads Info.plist files; never launches anything.
    public static func scan(roots: [URL]) -> [InstalledApp] {
        scanDetailed(roots: roots.map { ScanRoot($0) }, cache: AppIndexCache()).report.apps
    }

    public static func scan() -> [InstalledApp] { scanDetailed(roots: defaultRoots, cache: AppIndexCache()).report.apps }

    /// Finds apps, reusing `cache` entries whose Info.plist hasn't changed. Reads the remaining plists in parallel.
    public static func scanDetailed(roots: [ScanRoot], cache: AppIndexCache) -> (report: ScanReport, cache: AppIndexCache) {
        let started = Date()
        let fm = FileManager.default

        var urls: [URL] = []
        var seen = Set<String>()
        func collect(_ dir: URL, depth: Int) {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                                                          options: [.skipsHiddenFiles]) else { return }
            for item in items {
                if item.pathExtension == "app" {
                    if seen.insert(item.path).inserted { urls.append(item) }
                } else if depth > 0, (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    collect(item, depth: depth - 1)
                }
            }
        }
        for root in roots { collect(root.url, depth: root.depth) }

        var results = [InstalledApp?](repeating: nil, count: urls.count)
        var modifiedTimes = [TimeInterval](repeating: 0, count: urls.count)
        var reusedFlags = [Bool](repeating: false, count: urls.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: urls.count) { index in
            let url = urls[index]
            let plist = url.appendingPathComponent("Contents/Info.plist")
            let modified = (try? plist.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate?.timeIntervalSince1970 ?? 0
            var app: InstalledApp?
            var reused = false
            if let hit = cache.entries[url.path], hit.modified == modified, modified > 0 {
                app = hit.app
                reused = true
            } else {
                app = read(url)
            }
            lock.lock()
            results[index] = app
            modifiedTimes[index] = modified
            reusedFlags[index] = reused
            lock.unlock()
        }

        var found: [String: InstalledApp] = [:]
        var newCache = AppIndexCache()
        var reusedCount = 0
        for index in urls.indices {
            guard let app = results[index] else { continue }
            if found[app.bundleID] == nil { found[app.bundleID] = app }   // earlier roots win
            newCache.entries[urls[index].path] = AppIndexCache.Entry(modified: modifiedTimes[index], app: app)
            if reusedFlags[index] { reusedCount += 1 }
        }
        let apps = found.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let report = ScanReport(apps: apps, seconds: Date().timeIntervalSince(started), reused: reusedCount,
                                read: urls.count - reusedCount)
        return (report, newCache)
    }

    static func read(_ appURL: URL) -> InstalledApp? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String else { return nil }
        let name = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        let category = AppClassifier.classify(bundleID: bundleID, lsCategory: plist["LSApplicationCategoryType"] as? String,
                                              path: appURL.path, name: name)
        return InstalledApp(name: name, bundleID: bundleID, path: appURL.path, category: category)
    }
}
