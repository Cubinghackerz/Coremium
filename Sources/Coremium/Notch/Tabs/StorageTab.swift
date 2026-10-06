import CoremiumCore
import SwiftUI

@MainActor
final class StorageModel: ObservableObject {
    @Published var items: [StorageItem] = []
    @Published var selected: Set<String> = []
    @Published var scanning = false
    @Published var scanned = false
    @Published var disk: DiskUsage? = DiskUsage.current()
    @Published var message = ""
    @Published var expanded: Set<StorageKind> = []

    func scan() {
        guard !scanning else { return }
        scanning = true
        message = ""
        Task { @MainActor in
            let found = await Task.detached(priority: .utility) { StorageScanner.scan() }.value
            items = found
            // Nothing is pre-selected except safe-to-clear caches and logs; downloads always need a deliberate tick.
            selected = Set(found.filter { $0.kind == .appCaches || $0.kind == .logs || $0.kind == .developerBuilds }.map(\.id))
            disk = DiskUsage.current()
            scanning = false
            scanned = true
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

    func clean() {
        let chosen = selectedItems
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) { StorageCleaner.moveToTrash(chosen) }.value
            let moved = Set(chosen.map(\.id)).subtracting(result.failed.compactMap { name in chosen.first { $0.name == name }?.id })
            items.removeAll { moved.contains($0.id) }
            selected.subtract(moved)
            disk = DiskUsage.current()
            message = "Moved \(formatBytes(result.movedBytes)) to the Trash (\(result.movedCount) item\(result.movedCount == 1 ? "" : "s")). "
                + "Nothing is deleted until you empty the Trash, so you can put anything back."
                + (result.failed.isEmpty ? "" : " Couldn't move: \(result.failed.joined(separator: ", ")).")
        }
    }
}

extension StorageKind {
    /// Muted, distinct hues that sit quietly on the black panel.
    var tint: Color {
        switch self {
        case .appCaches: return Color(red: 0.42, green: 0.80, blue: 0.98)
        case .logs: return Color(red: 0.66, green: 0.58, blue: 0.98)
        case .developerBuilds: return Color(red: 0.96, green: 0.72, blue: 0.45)
        case .oldDownloads: return Color(red: 0.95, green: 0.50, blue: 0.70)
        case .trash: return Color(red: 0.58, green: 0.64, blue: 0.72)
        }
    }
    var symbol: String {
        switch self {
        case .appCaches: return "shippingbox.fill"
        case .logs: return "doc.text.fill"
        case .developerBuilds: return "hammer.fill"
        case .oldDownloads: return "arrow.down.circle.fill"
        case .trash: return "trash.fill"
        }
    }
}

/// The disk as one ring: each reclaimable kind is a coloured arc, the rest of what's used is grey, free space is dark.
private struct StorageRing: View {
    let disk: DiskUsage?
    let parts: [(StorageKind, Int64)]
    let focus: StorageKind?
    let scanning: Bool
    @State private var spin = false

    var body: some View {
        let total = Double(max(disk?.total ?? 1, 1))
        let segments = arcs(total: total)
        ZStack {
            Circle().stroke(Color.white.opacity(0.05), lineWidth: 14)
            ForEach(segments.indices, id: \.self) { i in
                let seg = segments[i]
                Circle().trim(from: seg.from, to: max(seg.from, seg.to - 0.004))
                    .stroke(seg.color.opacity(focus == nil || seg.kind == focus || seg.kind == nil ? 1 : 0.25),
                            style: StrokeStyle(lineWidth: seg.kind == focus && focus != nil ? 17 : 14, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            if scanning {
                Circle().trim(from: 0, to: 0.18)
                    .stroke(AngularGradient(colors: [.clear, .white.opacity(0.7)], center: .center), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(spin ? 270 : -90))
                    .onAppear { withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { spin = true } }
            }
            VStack(spacing: 1) {
                Text(disk.map { formatBytes($0.available) } ?? "–").font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundColor(.white).minimumScaleFactor(0.7).lineLimit(1)
                Text(disk.map { "free of \(formatBytes($0.total))" } ?? "").font(.system(size: 9.5, design: .rounded)).foregroundColor(Theme.textDim)
            }
            .padding(.horizontal, 22)
        }
        .animation(.easeOut(duration: 0.6), value: parts.map(\.1))
        .animation(.easeOut(duration: 0.25), value: focus)
    }

    private struct Arc { let from: CGFloat; let to: CGFloat; let color: Color; let kind: StorageKind? }

    private func arcs(total: Double) -> [Arc] {
        guard let disk else { return [] }
        var result: [Arc] = []
        var cursor: CGFloat = 0
        for (kind, bytes) in parts where bytes > 0 {
            let len = CGFloat(Double(bytes) / total)
            result.append(Arc(from: cursor, to: cursor + len, color: kind.tint, kind: kind))
            cursor += len
        }
        let other = CGFloat(Double(disk.used) / total) - cursor
        if other > 0 { result.append(Arc(from: cursor, to: cursor + other, color: Color.white.opacity(0.22), kind: nil)) }
        return result
    }
}

struct StorageTab: View {
    @ObservedObject var ui: NotchUIState
    @StateObject private var model = StorageModel()
    @State private var confirm = false
    @State private var focus: StorageKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 18) {
                StorageRing(disk: model.disk, parts: StorageKind.allCases.map { ($0, model.bytes($0)) }, focus: focus, scanning: model.scanning)
                    .frame(width: 138, height: 138)
                VStack(spacing: 2) {
                    ForEach(StorageKind.allCases, id: \.self) { kind in categoryRow(kind) }
                    otherRow
                }
            }
            detail
            footer
        }
        .onAppear { if !model.scanned && !model.scanning { model.scan() } }
        // Open the biggest reclaimable category once a scan finishes, so the space below the ring is never empty.
        .onChange(of: model.scanning) { scanning in
            guard !scanning, focus == nil else { return }
            focus = StorageKind.allCases.filter(\.cleanable).max { model.bytes($0) < model.bytes($1) }
        }
        .confirmationDialog("Move \(formatBytes(model.selectedBytes)) to the Trash?", isPresented: $confirm) {
            Button("Move to Trash") { model.clean() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("\(model.selectedItems.count) items. Nothing is deleted until you empty the Trash.") }
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
                        .font(.system(size: 13)).foregroundColor(someOn ? kind.tint : .white.opacity(0.28))
                }
                .buttonStyle(.plain).disabled(items.isEmpty)
                .help(allOn ? "Leave all \(kind.title.lowercased()) out" : "Include all \(kind.title.lowercased())")
            } else {
                Image(systemName: "lock.fill").font(.system(size: 10)).foregroundColor(.white.opacity(0.28)).frame(width: 13)
                    .help("Coremium never empties the Trash.")
            }
            Button { withAnimation(.easeOut(duration: 0.2)) { focus = focused ? nil : kind } } label: {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2.5).fill(kind.tint).frame(width: 9, height: 9)
                    Text(kind.title).font(.system(size: 12, weight: focused ? .semibold : .medium, design: .rounded))
                        .foregroundColor(.white.opacity(focused ? 1 : 0.85))
                    Spacer(minLength: 6)
                    Text(model.scanned ? formatBytes(bytes) : "…").font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit().foregroundColor(.white.opacity(bytes > 0 ? 0.9 : 0.35))
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(focused ? 0.8 : 0.25)).rotationEffect(.degrees(focused ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(kind.explanation)
        }
        .padding(.horizontal, 10).padding(.vertical, 5.5)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(focused ? 0.08 : 0)))
    }

    private var otherRow: some View {
        let reclaim = StorageKind.allCases.reduce(Int64(0)) { $0 + model.bytes($1) }
        let other = max(0, (model.disk?.used ?? 0) - reclaim)
        return HStack(spacing: 8) {
            Color.clear.frame(width: 13, height: 1)
            RoundedRectangle(cornerRadius: 2.5).fill(Color.white.opacity(0.22)).frame(width: 9, height: 9)
            Text("Everything else").font(.system(size: 12, design: .rounded)).foregroundColor(Theme.textDim)
            Spacer(minLength: 6)
            Text(formatBytes(other)).font(.system(size: 12, design: .rounded)).monospacedDigit().foregroundColor(Theme.textDim)
            Color.clear.frame(width: 8, height: 1)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .help("Apps, documents, photos and the system. Coremium never touches these.")
    }

    @ViewBuilder private var detail: some View {
        if let kind = focus {
            let items = model.items.filter { $0.kind == kind }
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.explanation).font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                FlexScroll {
                    VStack(spacing: 2) {
                        if items.isEmpty {
                            Text(model.scanned ? "Nothing large here." : "Scanning…").font(.system(size: 11, design: .rounded))
                                .foregroundColor(Theme.textDim).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                        }
                        ForEach(items.prefix(80)) { item in itemRow(item) }
                    }
                }
            }
            .padding(10)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(kind.tint.opacity(0.18), lineWidth: 1))
            .transition(.opacity)
        } else {
            Text(model.scanned
                 ? "Choose a category to see what's inside. Everything you clear goes to the Trash first, and documents are never touched."
                 : "Looking at caches, logs, Xcode build files, old downloads and the Trash. Read-only; nothing changes until you choose. macOS may ask once to let Coremium look in Downloads and the Trash.")
                .font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 2)
        }
    }

    private func itemRow(_ item: StorageItem) -> some View {
        let on = model.selected.contains(item.id)
        return HStack(spacing: 9) {
            if item.kind.cleanable {
                Button { model.toggle(item) } label: {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 12))
                        .foregroundColor(on ? item.kind.tint : .white.opacity(0.28))
                }.buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name).font(.system(size: 11.5, weight: .medium, design: .rounded)).lineLimit(1).truncationMode(.middle)
                if ui.advanced {
                    Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Theme.textDim).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer(minLength: 6)
            Text(formatBytes(item.bytes)).font(.system(size: 11, design: .rounded)).monospacedDigit().foregroundColor(.white.opacity(0.7))
            Button { NSWorkspace.shared.activateFileViewerSelecting([item.url]) } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 9.5)).foregroundColor(.white.opacity(0.35))
            }.buttonStyle(.plain).help("Show in Finder")
        }
        .padding(.vertical, 3).padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(model.message.isEmpty ? (model.scanning ? "Scanning…" : "Selected: \(formatBytes(model.selectedBytes))") : model.message)
                .font(.system(size: 10.5, design: .rounded)).foregroundColor(model.message.isEmpty ? Theme.textDim : Color(red: 0.45, green: 0.9, blue: 0.65))
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button { model.scan() } label: { Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold)) }
                .buttonStyle(GhostButtonStyle()).disabled(model.scanning).help("Scan again")
            Button(model.selectedItems.isEmpty ? "Move to Trash" : "Move \(formatBytes(model.selectedBytes)) to Trash") { confirm = true }
                .buttonStyle(PrimaryButtonStyle()).disabled(model.selectedItems.isEmpty || model.scanning).fixedSize()
        }
    }
}
