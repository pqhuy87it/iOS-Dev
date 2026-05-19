import SwiftUI

// MARK: - 1. MODELS (TripCollection, Activity, Trip)
enum TripCollection: String, CaseIterable, Identifiable {
    case springEscapes, summerVibes, fallGetaways, winterRetreats
    var id: Self { self }
}

@Observable
class Activity: Identifiable {
    let id = UUID()
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

@Observable
class Trip: Identifiable {
    let id = UUID()
    var name: String
    var collection: TripCollection
    var activities: [Activity.ID: Activity]
    let creationDate = Date.now

    init(name: String, collection: TripCollection, activities: [Activity] = []) {
        self.name = name
        self.collection = collection
        self.activities = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
    }
}

// MARK: - 2. DATA SOURCE & SEARCH LOGIC
@Observable
class DataSource {
    // Biến lưu trữ từ khóa tìm kiếm (được bind với thanh Search)
    var searchText = ""
    var trips: [Trip.ID: Trip] = [:]

    init() {
        // Tạo dữ liệu giả (Mock Data) để test tìm kiếm
        let sampleTrips = [
            Trip(name: "Cali Coastal Trails", collection: .springEscapes, activities: [
                Activity(name: "Hike Swallow's Point Trail"),
                Activity(name: "Bike the Monterey Bay Trail")
            ]),
            Trip(name: "Japan Mystique", collection: .springEscapes, activities: [
                Activity(name: "Walk the canal paths at sunrise"),
                Activity(name: "Get Matcha soft serve in Gion")
            ]),
            Trip(name: "Maui Rainforest", collection: .summerVibes, activities: [
                Activity(name: "Descend a waterfall")
            ])
        ]
        self.trips = Dictionary(uniqueKeysWithValues: sampleTrips.map { ($0.id, $0) })
    }

    var recentlyAddedTrips: [Trip] {
        Array(trips.values.sorted { $0.creationDate > $1.creationDate }.prefix(5))
    }
    
    // Hàm tìm Trip chứa Activity tương ứng
    func trip(containing activityId: Activity.ID) -> Trip? {
        trips.values.first { trip in trip.activities[activityId] != nil }
    }

    // LOGIC TÌM KIẾM CỐT LÕI (Từ extension của DataSource)
    var searchResults: [SearchSection] {
        // Nếu không gõ gì -> Hiển thị Recent
        if searchText.isEmpty {
            return [.recentlyCreatedTrips(Array(recentlyAddedTrips.prefix(3)))]
        } else {
            // Lọc Trips
            let matchingTrips = trips.values
                .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

            // Lọc Activities
            let matchingActivities = trips.values
                .flatMap { $0.activities.values }
                .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

            var sections: [SearchSection] = []

            if !matchingTrips.isEmpty { sections.append(.trips(matchingTrips)) }
            if !matchingActivities.isEmpty { sections.append(.activities(matchingActivities)) }

            return sections
        }
    }
}

// Phân loại kết quả tìm kiếm
enum SearchSection: Identifiable {
    case recentlyCreatedTrips([Trip])
    case trips([Trip])
    case activities([Activity])

    var id: String {
        switch self {
        case .recentlyCreatedTrips: return "recent"
        case .trips: return "trips"
        case .activities: return "activities"
        }
    }

    var title: String {
        switch self {
        case .recentlyCreatedTrips: return "Recently Created"
        case .trips: return "Trips"
        case .activities: return "Activities"
        }
    }
}

// MARK: - 3. VIEWS
struct SearchView: View {
    @Environment(DataSource.self) private var dataSource

    var body: some View {
        // @Bindable để cho phép truyền binding $dataSource.searchText xuống modifiers
        @Bindable var dataSource = dataSource

        NavigationStack {
            SearchResultsListView()
                .navigationTitle("Search")
                .toolbarTitleDisplayMode(.inline)
                // ĐÂY LÀ NƠI GẮN THANH SEARCH VÀO UI:
                .searchable(
                    text: $dataSource.searchText,
                    prompt: "Trips, Destinations and More."
                )
                // Ẩn bàn phím khi user scroll list
                .scrollDismissesKeyboard(.immediately)
        }
    }
}

struct SearchResultsListView: View {
    @Environment(DataSource.self) private var dataSource

    var body: some View {
        List(dataSource.searchResults) { section in
            SearchSectionView(section: section)
        }
        .overlay {
            // Màn hình trống (Empty State) khi gõ nhưng không có kết quả
            if dataSource.searchResults.isEmpty {
                ContentUnavailableView(
                    "No results for “\(dataSource.searchText)”",
                    systemImage: "magnifyingglass",
                    description: Text("Check spelling or try a new search.")
                )
            }
        }
        .listStyle(.plain)
    }
}

struct SearchSectionView: View {
    @Environment(DataSource.self) private var dataSource
    var section: SearchSection

    var body: some View {
        Section {
            switch section {
            case .recentlyCreatedTrips(let trips), .trips(let trips):
                ForEach(trips) { trip in
                    NavigationLink {
                        // Dummy Detail View (Thay cho TripDetailView phức tạp)
                        Text("Welcome to \(trip.name)!")
                            .font(.largeTitle)
                    } label: {
                        SearchItemView(name: trip.name)
                    }
                }
            case .activities(let activities):
                ForEach(activities) { activity in
                    NavigationLink {
                        if let trip = dataSource.trip(containing: activity.id) {
                            Text("This activity belongs to \(trip.name)")
                                .font(.title)
                        }
                    } label: {
                        Text(activity.name)
                            .font(.title3)
                            .fontWeight(.regular)
                    }
                }
            }
        } header: {
            Text(section.title)
                .font(.title3)
                .fontWeight(.semibold)
                // Đổi thành màu phụ thuộc theme (bỏ màu white cố định để dễ nhìn ở chế độ Light Mode)
                .foregroundStyle(.secondary)
        }
    }
}

struct SearchItemView: View {
    var name: String

    var body: some View {
        HStack(spacing: 16) {
            // Dummy Image (Thay cho TripImageView / AsyncImage)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "photo.fill").foregroundStyle(.gray)
                }

            Text(name)
                .font(.title3)
                .fontWeight(.regular)
        }
    }
}

// MARK: - 4. PREVIEW
#Preview {
    // Chạy thử view bằng cách Inject DataSource vào Environment
    @Previewable @State var dataSource = DataSource()
    SearchView()
        .environment(dataSource)
}
