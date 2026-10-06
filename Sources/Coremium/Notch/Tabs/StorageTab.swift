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

struct StorageTab: View {
    @ObservedObject var ui: NotchUIState
    @StateObject private var model = StorageModel()
    @State private var confirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if !model.scanned {
                Card(padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("See what's filling your Mac, and clear it safely.").font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("Coremium looks only at caches, logs, Xcode build files, old downloads and the Trash. Everything it clears goes to the Trash first, never deleted for good, and your documents are never touched. macOS may ask once to let Coremium look in Downloads and the Trash; if they show as empty, allow it in System Settings › Privacy & Security › Files and Folders.")
                            .font(.system(size: 11, design: .rounded)).foregroundColor(Theme.textDim).fixedSize(horizontal: false, vertical: true)
                        Button(model.scanning ? "Scanning…" : "Scan now") { model.scan() }
                            .buttonStyle(PrimaryButtonStyle()).disabled(model.scanning)
                    }
                }
            } else {
                FlexScroll {
                    VStack(spacing: 6) { ForEach(StorageKind.allCases, id: \.self) { kind in group(kind) } }
                }
                .frame(minHeight: 110, maxHeight: .infinity)
                footer
            }
        }
        .onAppear { if !model.scanned && !model.scanning { model.scan() } }
        .confirmationDialog("Move \(formatBytes(model.selectedBytes)) to the Trash?", isPresented: $confirm) {
            Button("Move to Trash") { model.clean() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("\(model.selectedItems.count) items. You can put them back from the Trash.") }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let disk = model.disk {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(LinearGradient(colors: [CoremiumLogo.cyan, CoremiumLogo.violet], startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * CGFloat(Double(disk.used) / Double(max(disk.total, 1))))
                    }
                }
                .frame(height: 8)
                Text("\(formatBytes(disk.available)) free of \(formatBytes(disk.total))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.85)).fixedSize()
            }
            Spacer(minLength: 0)
            if model.scanned {
                Button(model.scanning ? "Scanning…" : "Rescan") { model.scan() }.buttonStyle(GhostButtonStyle()).disabled(model.scanning)
            }
        }
    }

    @ViewBuilder private func group(_ kind: StorageKind) -> some View {
        let items = model.items.filter { $0.kind == kind }
        let total = model.bytes(kind)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button { if model.expanded.contains(kind) { model.expanded.remove(kind) } else { model.expanded.insert(kind) } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: model.expanded.contains(kind) ? "chevron.down" : "chevron.right").font(.system(size: 8, weight: .bold)).frame(width: 10)
                        Text(kind.title).font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text(formatBytes(total)).font(.system(size: 11, design: .rounded)).foregroundColor(Theme.textDim)
                    }
                }.buttonStyle(.plain).help(kind.explanation)
                Spacer()
                if kind.cleanable, !items.isEmpty {
                    Button(items.allSatisfy { model.selected.contains($0.id) } ? "Clear selection" : "Select all") {
                        model.setAll(kind, on: !items.allSatisfy { model.selected.contains($0.id) })
                    }.buttonStyle(.plain).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(CoremiumLogo.cyan)
                }
            }
            if items.isEmpty {
                Text("Nothing big here.").font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim).padding(.leading, 16)
            } else if model.expanded.contains(kind) || items.count <= 3 {
                ForEach(items.prefix(model.expanded.contains(kind) ? 60 : 3)) { item in row(item) }
            } else {
                ForEach(items.prefix(3)) { item in row(item) }
                Text("\(items.count - 3) more. Click \(kind.title) to see all.").font(.system(size: 10, design: .rounded)).foregroundColor(Theme.textDim).padding(.leading, 16)
            }
            if kind == .trash, !items.isEmpty {
                Text(kind.explanation).font(.system(size: 10, design: .rounded)).foregroundColor(Theme.textDim).padding(.leading, 16)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.05)))
    }

    private func row(_ item: StorageItem) -> some View {
        HStack(spacing: 8) {
            if item.kind.cleanable {
                Button { model.toggle(item) } label: {
                    Image(systemName: model.selected.contains(item.id) ? "checkmark.square.fill" : "square")
                        .foregroundColor(model.selected.contains(item.id) ? CoremiumLogo.cyan : .white.opacity(0.4))
                }.buttonStyle(.plain)
            } else {
                Image(systemName: "trash").foregroundColor(.white.opacity(0.3))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name).font(.system(size: 11.5, weight: .medium, design: .rounded)).lineLimit(1).truncationMode(.middle)
                if ui.advanced {
                    Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Theme.textDim).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer(minLength: 6)
            Text(formatBytes(item.bytes)).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.7)).fixedSize()
        }
        .padding(.leading, 16)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(model.message.isEmpty ? "Everything cleared goes to the Trash first." : model.message)
                .font(.system(size: 10.5, design: .rounded)).foregroundColor(model.message.isEmpty ? Theme.textDim : .green)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Move \(formatBytes(model.selectedBytes)) to Trash") { confirm = true }
                .buttonStyle(PrimaryButtonStyle()).disabled(model.selectedItems.isEmpty).fixedSize()
        }
    }
}
