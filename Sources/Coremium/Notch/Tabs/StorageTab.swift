import AppKit
import CoremiumCore
import SwiftUI

/// Lives for the whole app session, so closing the panel never loses or restarts a scan.
@MainActor
final class StorageModel: ObservableObject {
    static let shared = StorageModel()

    @Published var items: [StorageItem] = []
    @Published var selected: Set<String> = []
    @Published var pending: Set<StorageKind> = []
    @Published var waitingForPermission = false
    @Published var scanned = false
    @Published var disk: DiskUsage? = DiskUsage.current()
    @Published var message = ""
    @Published var reviewing = false
    /// Latest scan run per kind: a result is kept only if it belongs to the newest run for its own kind.
    private var runs: [StorageKind: Int] = [:]
    private var counter = 0

    var scanning: Bool { !pending.isEmpty }

    /// Scans each kind on its own, so a slow folder (or a macOS permission prompt) never holds up the others.
    func scan(_ kinds: [StorageKind] = StorageKind.standard) {
        guard pending.isDisjoint(with: kinds) else { return }
        counter += 1
        let run = counter
        for kind in kinds { runs[kind] = run }
        message = ""
        waitingForPermission = false
        items.removeAll { kinds.contains($0.kind) }
        pending.formUnion(kinds)
        for kind in kinds {
            Task { @MainActor in
                let found = await Task.detached(priority: .utility) {
                    kind == .largeFiles ? StorageScanner.largeFiles() : StorageScanner.scan(kinds: [kind])
                }.value
                guard runs[kind] == run else { return }
                items.append(contentsOf: found)
                items.sort { $0.bytes > $1.bytes }
                // Safe-to-clear kinds start selected; your downloads always need a deliberate tick.
                if [.appCaches, .logs, .developerBuilds].contains(kind) { selected.formUnion(found.map(\.id)) }
                pending.remove(kind)
                if pending.isEmpty { waitingForPermission = false; scanned = true; disk = DiskUsage.current() }
            }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            if kinds.contains(where: { runs[$0] == run && pending.contains($0) }) { waitingForPermission = true }
        }
    }

    func bytes(_ kind: StorageKind, selectedOnly: Bool = false) -> Int64 {
        items.filter { $0.kind == kind && (!selectedOnly || selected.contains($0.id)) }.reduce(0) { $0 + $1.bytes }
    }

    var selectedItems: [StorageItem] { items.filter { selected.contains($0.id) && $0.kind.cleanable } }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.bytes } }

    func toggle(_ item: StorageItem) {
        if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
    }

    func setAll(_ kind: StorageKind, on: Bool) {
        for item in items where item.kind == kind { if on { selected.insert(item.id) } else { selected.remove(item.id) } }
    }

    /// Caches that belong to an app that is running right now: moving them could upset it, so they are skipped.
    var inUseCaches: [StorageItem] {
        let ids = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let names = Set(NSWorkspace.shared.runningApplications.compactMap(\.localizedName))
        return selectedItems.filter {
            $0.kind == .appCaches && StorageCleaner.cacheBelongsToRunningApp($0.name, bundleIDs: ids, appNames: names)
        }
    }

    func clean() {
        let chosen = selectedItems
        let skip = Set(inUseCaches.map(\.id))
        reviewing = false
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) { StorageCleaner.moveToTrash(chosen, skip: skip) }.value
            let failedNames = Set(result.failed)
            let moved = Set(chosen.filter { !skip.contains($0.id) && !failedNames.contains($0.name) }.map(\.id))
            items.removeAll { moved.contains($0.id) }
            selected.subtract(moved)
            disk = DiskUsage.current()
            var text = "Moved \(formatBytes(result.movedBytes)) to the Trash. Nothing is deleted until you empty it."
            if !skip.isEmpty { text += " Skipped \(skip.count) cache\(skip.count == 1 ? "" : "s") of running apps." }
            if !result.failed.isEmpty { text += " Couldn't move \(result.failed.count)." }
            message = text
        }
    }
}

extension StorageKind {
    /// Muted colours so each arc of the ring can be told apart at a glance.
    var tint: Color {
        switch self {
        case .appCaches: return Theme.yield
        case .developerBuilds: return Theme.boost
        case .oldDownloads: return Color(red: 0.95, green: 0.58, blue: 0.72)
        case .logs: return Theme.gpu
        case .trash: return Color(white: 0.55)
        case .largeFiles: return Color(white: 0.4)
        }
    }
}

/// The disk as one ring: each reclaimable kind is an arc, the rest of what's used is a faint arc, free space is empty.
private struct StorageRing: View {
    let disk: DiskUsage?
    let parts: [(StorageKind, Int64)]
    let focus: StorageKind?
    let scanning: Bool
    @State private var spin = false

    var body: some View {
        let total = Double(max(disk?.total ?? 1, 1))
        ZStack {
            Circle().stroke(Color.white.opacity(0.045), lineWidth: 12)
            ForEach(Array(arcs(total: total).enumerated()), id: \.offset) { _, seg in
                Circle().trim(from: seg.from, to: max(seg.from, seg.to - 0.003))
                    .stroke(seg.color.opacity(focus == nil || seg.kind == focus || seg.kind == nil ? 1 : 0.22),
                            style: StrokeStyle(lineWidth: seg.kind != nil && seg.kind == focus ? 15 : 12, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            if scanning {
                Circle().trim(from: 0, to: 0.22)
                    .stroke(AngularGradient(colors: [.clear, .white.opacity(0.85)], center: .center), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(spin ? 270 : -90))
                    .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { spin = true } }
            }
            VStack(spacing: 2) {
                Text(disk.map { formatBytes($0.available) } ?? "–").font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit().foregroundColor(.white).minimumScaleFactor(0.7).lineLimit(1)
                Text("available").font(.system(size: 9.5, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 20)
        }
        .animation(.easeOut(duration: 0.6), value: parts.map(\.1))
        .animation(.easeOut(duration: 0.25), value: focus)
    }

    private struct Arc { let from: CGFloat; let to: CGFloat; let color: Color; let kind: StorageKind? }

    private func arcs(total: Double) -> [Arc] {
        guard let disk else { return [] }
        var result: [Arc] = []
        var cursor: CGFloat = 0
        for (kind, bytes) in parts where bytes > 0 && kind != .largeFiles {
            let len = CGFloat(Double(bytes) / total)
            result.append(Arc(from: cursor, to: cursor + len, color: kind.tint, kind: kind))
            cursor += len
        }
        let other = CGFloat(Double(disk.used) / total) - cursor
        if other > 0 { result.append(Arc(from: cursor, to: cursor + other, color: Color.white.opacity(0.14), kind: nil)) }
        return result
    }
}

struct StorageTab: View {
    @ObservedObject var ui: NotchUIState
    @ObservedObject private var model = StorageModel.shared
    @State private var focus: StorageKind?

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 20) {
                    StorageRing(disk: model.disk, parts: StorageKind.allCases.map { ($0, model.bytes($0)) }, focus: focus, scanning: model.scanning)
                        .frame(width: 132, height: 132)
                    VStack(spacing: 1) {
                        ForEach(StorageKind.standard, id: \.self) { kind in categoryRow(kind) }
                        largeFilesRow
                    }
                }
                detail
                footer
            }
            .blur(radius: model.reviewing ? 6 : 0)
            .allowsHitTesting(!model.reviewing)
            if model.reviewing { ReviewSheet(model: model).transition(.opacity.combined(with: .scale(scale: 0.98))) }
        }
        .animation(.easeOut(duration: 0.2), value: model.reviewing)
        .onAppear { if !model.scanned && !model.scanning { model.scan() } }
        .onChange(of: model.scanning) { scanning in
            guard !scanning, focus == nil else { return }
            focus = StorageKind.standard.filter(\.cleanable).max { model.bytes($0) < model.bytes($1) }
        }
    }

    private func categoryRow(_ kind: StorageKind) -> some View {
        let items = model.items.filter { $0.kind == kind }
        let bytes = model.bytes(kind)
        let allOn = !items.isEmpty && items.allSatisfy { model.selected.contains($0.id) }
        let someOn = items.contains { model.selected.contains($0.id) }
        let focused = focus == kind
        return HStack(spacing: 9) {
            if kind.cleanable {
                Button { model.setAll(kind, on: !allOn) } label: {
                    Image(systemName: allOn ? "checkmark.circle.fill" : someOn ? "minus.circle.fill" : "circle")
                        .font(.system(size: 12.5)).foregroundColor(someOn ? kind.tint : .white.opacity(0.25))
                }
                .buttonStyle(.plain).disabled(items.isEmpty)
                .help(allOn ? "Leave all \(kind.title.lowercased()) out" : "Include all \(kind.title.lowercased())")
            } else {
                Image(systemName: "lock.fill").font(.system(size: 9.5)).foregroundColor(.white.opacity(0.25)).frame(width: 12.5)
                    .help(kind.explanation)
            }
            Button { withAnimation(.easeOut(duration: 0.2)) { focus = focused ? nil : kind } } label: {
                HStack(spacing: 8) {
                    Circle().fill(kind.tint).frame(width: 7, height: 7)
                    Text(kind.title).font(.system(size: 12, weight: focused ? .semibold : .regular, design: .rounded))
                        .foregroundColor(.white.opacity(focused ? 1 : 0.8))
                    Spacer(minLength: 6)
                    Group {
                        if model.pending.contains(kind) { ProgressView().controlSize(.mini) }
                        else { Text(formatBytes(bytes)).monospacedDigit() }
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(bytes > 0 ? 0.9 : 0.3))
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(focused ? 0.7 : 0.2)).rotationEffect(.degrees(focused ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(kind.explanation)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(focused ? 0.07 : 0)))
    }

    private var largeFilesRow: some View {
        let found = model.items.filter { $0.kind == .largeFiles }
        let focused = focus == .largeFiles
        return HStack(spacing: 9) {
            Image(systemName: "eye").font(.system(size: 9.5)).foregroundColor(.white.opacity(0.3)).frame(width: 12.5)
                .help("Review only. Coremium never moves your own files.")
            if found.isEmpty && !model.pending.contains(.largeFiles) {
                Text("Large files").font(.system(size: 12, design: .rounded)).foregroundColor(.white.opacity(0.55))
                Spacer()
                Button("Find") { focus = .largeFiles; model.scan([.largeFiles]) }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.white)
                    .help("Looks for files over 500 MB in Desktop, Documents, Movies and Downloads. macOS may ask for permission.")
            } else {
                Button { withAnimation(.easeOut(duration: 0.2)) { focus = focused ? nil : .largeFiles } } label: {
                    HStack(spacing: 8) {
                        Text("Large files").font(.system(size: 12, weight: focused ? .semibold : .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer(minLength: 6)
                        if model.pending.contains(.largeFiles) { ProgressView().controlSize(.mini) }
                        else { Text(formatBytes(model.bytes(.largeFiles))).font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit() }
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(focused ? 0.7 : 0.2)).rotationEffect(.degrees(focused ? 90 : 0))
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(focused ? 0.07 : 0)))
    }

    @ViewBuilder private var detail: some View {
        if model.waitingForPermission {
            note("Still waiting on \(model.pending.map(\.title).sorted().joined(separator: ", ")). macOS may be showing a permission dialog behind other windows: allow it, or turn Coremium on in System Settings › Privacy & Security › Files and Folders.")
        } else if let kind = focus {
            let items = model.items.filter { $0.kind == kind }
            VStack(alignment: .leading, spacing: 6) {
                Text(kind.explanation).font(.system(size: 10.5, design: .rounded)).foregroundColor(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                FlexScroll {
                    VStack(spacing: 0) {
                        if items.isEmpty {
                            Text(model.pending.contains(kind) ? "Looking…" : "Nothing large here.").font(.system(size: 11, design: .rounded))
                                .foregroundColor(.white.opacity(0.45)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                        }
                        ForEach(items.prefix(80)) { item in itemRow(item) }
                    }
                }
            }
            .padding(12)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.035)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        } else {
            note(model.scanned ? "Choose a category to see what's inside." :
                 "Reading caches, logs, Xcode build files, old downloads and the Trash. Read-only: nothing changes until you choose and confirm.")
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 10.5, design: .rounded)).foregroundColor(.white.opacity(0.5))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(.horizontal, 2)
    }

    private func itemRow(_ item: StorageItem) -> some View {
        let on = model.selected.contains(item.id)
        return HStack(spacing: 9) {
            if item.kind.cleanable {
                Button { model.toggle(item) } label: {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 12))
                        .foregroundColor(on ? item.kind.tint : .white.opacity(0.25))
                }.buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name).font(.system(size: 11.5, design: .rounded)).foregroundColor(.white.opacity(0.9)).lineLimit(1).truncationMode(.middle)
                if ui.advanced || item.kind == .largeFiles {
                    Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4)).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer(minLength: 6)
            Text(formatBytes(item.bytes)).font(.system(size: 11, design: .rounded)).monospacedDigit().foregroundColor(.white.opacity(0.65))
            Button { NSWorkspace.shared.activateFileViewerSelecting([item.url]) } label: {
                Image(systemName: "arrow.up.forward.square").font(.system(size: 10)).foregroundColor(.white.opacity(0.35))
            }.buttonStyle(.plain).help("Show in Finder")
        }
        .padding(.vertical, 4).padding(.horizontal, 2)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1) }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(model.message.isEmpty
                 ? (model.scanning ? "Scanning…" : "\(formatBytes(model.selectedBytes)) selected · goes to the Trash, never deleted")
                 : model.message)
                .font(.system(size: 10.5, design: .rounded)).foregroundColor(.white.opacity(model.message.isEmpty ? 0.5 : 0.85))
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button { model.scan() } label: { Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold)) }
                .buttonStyle(GhostButtonStyle()).disabled(model.scanning).help("Scan again")
            Button("Review…") { model.reviewing = true }
                .buttonStyle(PrimaryButtonStyle()).disabled(model.selectedItems.isEmpty).fixedSize()
        }
    }
}

/// The last step before anything moves: what, how much, and the warnings that matter. Nothing happens until confirmed.
private struct ReviewSheet: View {
    @ObservedObject var model: StorageModel

    var body: some View {
        let chosen = model.selectedItems
        let inUse = model.inUseCaches
        let downloads = chosen.filter { $0.kind == .oldDownloads }
        VStack(alignment: .leading, spacing: 12) {
            Text("Move \(formatBytes(chosen.filter { item in !inUse.contains(item) }.reduce(0) { $0 + $1.bytes })) to the Trash?")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
            VStack(alignment: .leading, spacing: 4) {
                ForEach(StorageKind.standard.filter(\.cleanable), id: \.self) { kind in
                    let group = chosen.filter { $0.kind == kind }
                    if !group.isEmpty {
                        HStack {
                            Circle().fill(kind.tint).frame(width: 6, height: 6)
                            Text("\(kind.title) · \(group.count) item\(group.count == 1 ? "" : "s")").font(.system(size: 12, design: .rounded))
                            Spacer()
                            Text(formatBytes(group.reduce(0) { $0 + $1.bytes })).font(.system(size: 12, design: .rounded)).monospacedDigit()
                        }
                        .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                warning("Everything goes to the Trash. Nothing is deleted until you empty it, so you can put anything back.", icon: "arrow.uturn.backward")
                if !downloads.isEmpty {
                    warning("Includes \(downloads.count) of your downloads. Make sure you don't need them.", icon: "exclamationmark.triangle", strong: true)
                }
                if !inUse.isEmpty {
                    warning("Skipping caches of apps that are open (\(inUse.prefix(3).map(\.name).joined(separator: ", "))\(inUse.count > 3 ? "…" : "")). Quit them first to clear those too.", icon: "pause.circle")
                }
                if chosen.contains(where: { $0.kind == .appCaches }) {
                    warning("Apps rebuild their caches, so some may be slower the next time they open.", icon: "clock")
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { model.reviewing = false }.buttonStyle(GhostButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Move to Trash") { model.clean() }.buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: 440)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(white: 0.07)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 30, y: 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func warning(_ text: String, icon: String, strong: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.system(size: 11)).frame(width: 14)
                .foregroundColor(strong ? Theme.warn : .white.opacity(0.5))
            Text(text).font(.system(size: 11.5, design: .rounded)).foregroundColor(.white.opacity(strong ? 0.95 : 0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
