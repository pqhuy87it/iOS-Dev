//
//  OutboxUploadDemoApp.swift
//

import SwiftUI

@main
struct OutboxUploadDemoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var engine = SyncEngine.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                // Yêu cầu của bài: xin thêm giờ đúng lúc app xuống background.
                //
                // Ghi chú thực tế: production thường gọi beginBackgroundTask
                // ngay lúc BẮT ĐẦU công việc, không đợi tới đây — vì giữa
                // willResignActive và didEnterBackground có một khoảng ngắn
                // mà bạn có thể đã bị suspend. Xem README mục 6.
                SyncEngine.shared.handleDidEnterBackground()

            case .active:
                SyncEngine.shared.handleWillEnterForeground()
                // Yêu cầu của bài: mở app là tự chạy.
                SyncEngine.shared.start()

            case .inactive:
                break

            @unknown default:
                break
            }
        }
    }
}

struct ContentView: View {

    @EnvironmentObject private var engine: SyncEngine
    @ObservedObject private var logger = Logger.shared

    @State private var latency: Double = 1.5
    @State private var showGrants = true

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {

                progressCard
                controls

                if showGrants { grantsCard }

                Divider()

                HStack {
                    Text("Log").font(.subheadline.weight(.medium))
                    Spacer()
                    Button("Xoá") { logger.clear() }.font(.caption)
                }
                logView
            }
            .padding()
            .navigationTitle("Outbox upload")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Seed 5000 record", systemImage: "plus.circle") {
                            OutboxStore.shared.seed(count: 5000)
                            engine.refreshCounts()
                        }
                        Button("Đặt lại synced = 0", systemImage: "arrow.counterclockwise") {
                            OutboxStore.shared.unmarkAll()
                            engine.refreshCounts()
                        }
                        Button("Xoá DB", systemImage: "trash", role: .destructive) {
                            OutboxStore.shared.reset()
                            engine.refreshCounts()
                        }
                        Divider()
                        Button("Xoá lịch sử đo", systemImage: "chart.bar.xaxis") {
                            engine.clearGrants()
                        }
                        Toggle("Hiện lịch sử đo", isOn: $showGrants)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear { engine.refreshCounts() }
    }

    // MARK: - Card tiến trình

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(engine.syncedRecords) / \(engine.totalRecords)")
                    .font(.title2.weight(.medium))
                    .monospacedDigit()
                Spacer()
                if engine.isRunning {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.small)
                        Text("đang chạy").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            ProgressView(
                value: Double(engine.syncedRecords),
                total: Double(max(engine.totalRecords, 1))
            )

            HStack {
                Label("\(engine.batchesThisRun) batch phiên này", systemImage: "shippingbox")
                Spacer()
                Label(engine.remainingTimeText, systemImage: "clock")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Điều khiển

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    engine.start()
                } label: {
                    Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(engine.isRunning)

                Button {
                    engine.stop(reason: "user bấm Stop")
                } label: {
                    Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!engine.isRunning)
            }

            HStack {
                Text("Latency / batch")
                Slider(value: $latency, in: 0.2...10, step: 0.2) {
                    EmptyView()
                }
                .onChange(of: latency) { _, v in engine.simulatedLatency = v }
                Text(String(format: "%.1fs", latency))
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Lịch sử đo grant

    private var grantsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lịch sử background time đo được")
                .font(.subheadline.weight(.medium))

            if engine.grants.isEmpty {
                Text("Chưa có. Bấm Start rồi vuốt về Home để đo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(engine.grants.prefix(6)) { grant in
                    HStack(spacing: 8) {
                        Image(systemName: grant.actualUntilExpiration != nil
                              ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(grant.actualUntilExpiration != nil ? .orange : .green)
                            .font(.caption)

                        if let actual = grant.actualUntilExpiration {
                            Text("hết giờ sau \(String(format: "%.1f", actual))s")
                        } else if let done = grant.finishedAfter {
                            Text("xong sau \(String(format: "%.1f", done))s")
                        }

                        Text("· iOS báo \(String(format: "%.0f", grant.reportedAtEntry))s")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(grant.batchesUploadedInBackground) batch")
                            .foregroundStyle(.secondary)

                        if grant.lowPowerMode {
                            Image(systemName: "battery.25").foregroundStyle(.orange)
                        }
                    }
                    .font(.caption.monospacedDigit())
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Log

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
