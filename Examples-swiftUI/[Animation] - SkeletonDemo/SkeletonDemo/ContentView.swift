//
//  RoomListSkeletonDemo.swift
//
//  Skeleton loading bằng kỹ thuật redaction: RoomRow là nguồn sự thật duy nhất
//  cho cả trạng thái loading và trạng thái có dữ liệu. Không có view skeleton riêng.
//
//  Yêu cầu: iOS 17+ (dùng @Observable và ContentUnavailableView).
//  Cách chạy: tạo project SwiftUI mới, dán file này vào, đặt RoomListView() làm root view.
//

import SwiftUI

// MARK: - Model

struct Room: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let hostName: String
    let viewerCount: Int
    let isLive: Bool
    let thumbnailURL: URL?
}

extension Room {

    /// Dữ liệu giả để render skeleton.
    ///
    /// Hai điều kiện bắt buộc:
    /// 1. Độ dài chuỗi phải tương đương dữ liệu thật. `.redacted` biến mỗi `Text`
    ///    thành một thanh xám có chiều rộng đúng bằng chiều rộng chuỗi gốc, nên
    ///    chuỗi quá ngắn sẽ cho skeleton nhìn nhỏ xíu, quá dài thì tràn dòng.
    /// 2. `id` phải khác nhau. `List` cần id ổn định và duy nhất, nếu trùng thì
    ///    diffing sai và animation lúc load xong sẽ giật.
    static func placeholders(count: Int = 6) -> [Room] {
        let titles = [
            "Đang tải tiêu đề phòng phát",
            "Đang tải tiêu đề dài hơn một chút",
            "Đang tải tiêu đề",
            "Đang tải nội dung phòng livestream",
        ]
        let hosts = ["Đang tải host", "Tên host đang tải", "Host"]
        let counts = [128, 2_450, 17_300, 890]

        return (0..<count).map { index in
            Room(
                id: "placeholder-\(index)",
                title: titles[index % titles.count],
                hostName: hosts[index % hosts.count],
                viewerCount: counts[index % counts.count],
                isLive: index % 3 != 0,
                thumbnailURL: nil
            )
        }
    }
}

// MARK: - Service

protocol RoomServicing: Sendable {
    func fetchRooms() async throws -> [Room]
}

/// Service giả: chờ 2.5 giây rồi decode một chuỗi JSON.
struct MockRoomService: RoomServicing {

    var delay: Duration = .seconds(2.5)
    var shouldFail: Bool = false

    private static let mockJSON = """
    [
      {
        "id": "room-01",
        "title": "Unbox iPhone mới, có quà cho 100 người đầu",
        "host_name": "Minh Trang Studio",
        "viewer_count": 18432,
        "is_live": true,
        "thumbnail_url": null
      },
      {
        "id": "room-02",
        "title": "Cày rank Liên Quân cùng team",
        "host_name": "Đức Anh Gaming",
        "viewer_count": 5210,
        "is_live": true,
        "thumbnail_url": null
      },
      {
        "id": "room-03",
        "title": "Học Swift từ số 0 — buổi 12: Concurrency",
        "host_name": "iOS Vietnam",
        "viewer_count": 764,
        "is_live": true,
        "thumbnail_url": null
      },
      {
        "id": "room-04",
        "title": "Cà phê sáng và nhạc acoustic",
        "host_name": "Hà Nội Coffee",
        "viewer_count": 342,
        "is_live": false,
        "thumbnail_url": null
      },
      {
        "id": "room-05",
        "title": "Review đồ bếp giá dưới 200k",
        "host_name": "Bếp Nhà Mẹ Hương",
        "viewer_count": 9187,
        "is_live": true,
        "thumbnail_url": null
      },
      {
        "id": "room-06",
        "title": "Talkshow: làm sản phẩm ở startup",
        "host_name": "Product Talk",
        "viewer_count": 1203,
        "is_live": false,
        "thumbnail_url": null
      }
    ]
    """

    func fetchRooms() async throws -> [Room] {
        try await Task.sleep(for: delay)

        if shouldFail {
            throw URLError(.timedOut)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Room].self, from: Data(Self.mockJSON.utf8))
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class RoomListViewModel {

    enum State {
        case loading
        case loaded([Room])
        case failed(String)
    }

    /// Thời gian tối thiểu skeleton phải hiện. Nếu API trả về sau 80ms mà không có
    /// mức sàn này thì skeleton chớp một cái rồi biến mất, gây cảm giác giật.
    private static let minimumSkeletonDuration: Duration = .milliseconds(600)

    private(set) var state: State = .loading

    private let service: RoomServicing

    init(service: RoomServicing) {
        self.service = service
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    /// Nguồn dữ liệu duy nhất cho `List`. Lúc loading thì trả về placeholder,
    /// nên view không cần biết mình đang ở trạng thái nào.
    var displayedRooms: [Room] {
        switch state {
        case .loading:
            return Room.placeholders()
        case .loaded(let rooms):
            return rooms
        case .failed:
            return []
        }
    }

    func load() async {
        state = .loading
        let startedAt = ContinuousClock.now

        do {
            let rooms = try await service.fetchRooms()
            await holdSkeleton(since: startedAt)
            state = .loaded(rooms)
        } catch is CancellationError {
            return
        } catch {
            await holdSkeleton(since: startedAt)
            state = .failed("Không tải được danh sách phòng. Kiểm tra kết nối rồi thử lại.")
        }
    }

    private func holdSkeleton(since startedAt: ContinuousClock.Instant) async {
        let elapsed = ContinuousClock.now - startedAt
        guard elapsed < Self.minimumSkeletonDuration else { return }
        try? await Task.sleep(for: Self.minimumSkeletonDuration - elapsed)
    }
}

// MARK: - Shimmer

private struct ShimmerModifier: ViewModifier {

    let isActive: Bool

    @State private var phase: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if isActive && !reduceMotion {
                band
                    // Overlay không được nuốt touch của nội dung bên dưới.
                    .allowsHitTesting(false)
                    .clipped()
            }
        }
    }

    private var band: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let bandWidth = max(width * 0.4, 80)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(colorScheme == .dark ? 0.14 : 0.55), location: 0.5),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: bandWidth)
            .offset(x: -bandWidth + phase * (width + bandWidth))
            // plusLighter làm dải sáng hoạt động ở cả light và dark mode.
            .blendMode(.plusLighter)
            .task {
                phase = 0
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
    }
}

extension View {
    func shimmering(isActive: Bool) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - RoomRow

/// Đây là toàn bộ điểm mấu chốt của bài này: chỉ có một view.
/// Sửa layout ở đây thì skeleton tự đổi theo, không thể lệch.
struct RoomRow: View {

    let room: Room

    @Environment(\.redactionReasons) private var redactionReasons

    private var isPlaceholder: Bool {
        redactionReasons.contains(.placeholder)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 6) {
                Text(room.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(room.hostName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    if room.isLive {
                        liveBadge
                    }
                    Text("\(room.viewerCount.formatted(.number.notation(.compactName))) người xem")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        // Chốt chiều cao tối thiểu để hai trạng thái cao bằng nhau, tránh layout shift.
        .frame(minHeight: 75, alignment: .top)
    }

    /// `.redacted` chỉ che `Text` và `Image`. Shape và màu nền thì KHÔNG bị che,
    /// nên nếu để nguyên `.red` thì lúc skeleton sẽ có một capsule đỏ chói giữa
    /// đám thanh xám. Đây là cái bẫy hay gặp nhất của kỹ thuật này.
    private var liveBadge: some View {
        Text("LIVE")
            .font(.caption2.weight(.bold))
            .foregroundStyle(isPlaceholder ? Color.clear : .white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isPlaceholder ? Color.clear : Color.red, in: Capsule())
    }

    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.secondary.opacity(0.18))
            .frame(width: 112, height: 63)
            .overlay {
                // Không gọi network cho dữ liệu giả. Nếu bỏ điều kiện này thì
                // mỗi lần loading sẽ bắn 6 request ảnh vô nghĩa.
                if !isPlaceholder, let url = room.thumbnailURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - RoomListView

struct RoomListView: View {

    @State private var viewModel: RoomListViewModel

    init(service: RoomServicing = MockRoomService()) {
        _viewModel = State(initialValue: RoomListViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Phòng phát")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Tải lại", systemImage: "arrow.clockwise") {
                            Task { await viewModel.load() }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if case .failed(let message) = viewModel.state {
            ContentUnavailableView {
                Label("Danh sách trống", systemImage: "antenna.radiowaves.left.and.right.slash")
            } description: {
                Text(message)
            } actions: {
                Button("Thử lại") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            list
        }
    }

    private var list: some View {
        List(viewModel.displayedRooms) { room in
            RoomRow(room: room)
        }
        .listStyle(.plain)
        // Ba dòng dưới đây là toàn bộ cơ chế skeleton.
        .redacted(reason: viewModel.isLoading ? .placeholder : [])
        .shimmering(isActive: viewModel.isLoading)
        .disabled(viewModel.isLoading)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isLoading)
        .refreshable { await viewModel.load() }
        // VoiceOver không nên đọc nội dung giả.
        .accessibilityHidden(viewModel.isLoading)
        .overlay {
            if viewModel.isLoading {
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel("Đang tải danh sách phòng")
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }
}

// MARK: - Preview

#Preview("Bình thường — chờ 2.5s") {
    RoomListView()
}

#Preview("Mạng chậm — chờ 6s") {
    RoomListView(service: MockRoomService(delay: .seconds(6)))
}

#Preview("API nhanh — kiểm tra mức sàn 600ms") {
    RoomListView(service: MockRoomService(delay: .milliseconds(50)))
}

#Preview("Lỗi") {
    RoomListView(service: MockRoomService(delay: .seconds(1), shouldFail: true))
}
