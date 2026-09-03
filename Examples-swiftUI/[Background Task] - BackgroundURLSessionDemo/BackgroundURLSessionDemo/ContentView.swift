import SwiftUI
import Combine

struct ContentView: View {

    @StateObject private var progress = IconSyncService.shared.progress
    @ObservedObject private var logger = Logger.shared
    @Environment(\.scenePhase) private var scenePhase

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {

                header

                if progress.icons.isEmpty {
                    ContentUnavailableView(
                        "Chưa có icon",
                        systemImage: "square.grid.2x2",
                        description: Text("Bấm Sync, hoặc gửi silent push để thử.")
                    )
                    .frame(height: 160)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(progress.icons, id: \.id) { icon in
                                IconCell(id: icon.id, url: icon.url)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }

                Divider()
                statusRow
                Divider()

                Text("Log")
                    .font(.subheadline.weight(.medium))

                logView
            }
            .padding()
            .navigationTitle("Icon sync")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await IconSyncService.shared.syncNow(reason: "manual") }
                    } label: {
                        if progress.isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(progress.isSyncing)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Xoá log", systemImage: "text.badge.xmark") { logger.clear() }
                        Button("Reset toàn bộ", systemImage: "trash", role: .destructive) {
                            IconStore.shared.resetEverything()
                            progress.reload()
                            Logger.shared.log("🗑️ reset toàn bộ state + file")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear { progress.reload() }
        .onChange(of: scenePhase) { _, phase in
            Logger.shared.log("📱 scenePhase → \(String(describing: phase))")
            if phase == .active {
                // Mỗi lần về foreground: install nốt staged + đối chiếu lại.
                // Khoảng thời gian app ở background là một lỗ hổng, phải bù.
                IconStore.shared.installStaged()
                progress.reload()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Manifest version: \(IconStore.shared.manifestVersion)")
                .font(.subheadline)
            Text(SyncConfig.manifestURL.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var statusRow: some View {
        let counts = Dictionary(grouping: progress.records.values, by: \.state)
            .mapValues(\.count)
        return HStack(spacing: 16) {
            badge("installed", counts[.installed] ?? 0, .green)
            badge("pending", counts[.pending] ?? 0, .orange)
            badge("staged", counts[.staged] ?? 0, .blue)
            badge("failed", counts[.failed] ?? 0, .red)
        }
        .font(.caption)
    }

    private func badge(_ label: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(label) \(count)").foregroundStyle(.secondary)
        }
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(logger.lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                    }
                }
            }
            .onChange(of: logger.lines.count) { _, _ in
                if let last = logger.lines.indices.last {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
    }
}

private struct IconCell: View {
    let id: String
    let url: URL

    var body: some View {
        VStack(spacing: 4) {
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "exclamationmark.triangle"))
            }
            Text(id)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
