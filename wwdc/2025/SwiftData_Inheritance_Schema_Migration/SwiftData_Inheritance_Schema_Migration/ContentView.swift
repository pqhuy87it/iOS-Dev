import SwiftUI
import SwiftData

enum TripFilterType: String, CaseIterable {
    case all = "Tất cả"
    case personal = "Cá nhân"
    case business = "Công tác"
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var filterType: TripFilterType = .all
    @State private var searchText: String = ""
    
    var body: some View {
        NavigationStack {
            // Truyền trạng thái lọc và tìm kiếm vào Subview chứa @Query
            TripListView(filterType: filterType, searchText: searchText)
                .searchable(text: $searchText, prompt: "Tìm điểm đến...")
                .toolbar {
                    // Segmented Control để chọn loại chuyến đi
                    ToolbarItem(placement: .principal) {
                        Picker("Loại", selection: $filterType) {
                            ForEach(TripFilterType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Nút thêm dữ liệu mẫu để test
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: addDummyData) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .navigationTitle("Chuyến đi")
        }
    }
    
    // Hàm tạo dữ liệu mẫu
    private func addDummyData() {
        let personal = PersonalTrip(destination: "Đà Lạt", startDate: Date(), endDate: Date().addingTimeInterval(86400 * 3), reason: .vacation)
        let business = BusinessTrip(destination: "Hà Nội", startDate: Date(), endDate: Date().addingTimeInterval(86400 * 2), perDiem: 500000)
        
        modelContext.insert(personal)
        modelContext.insert(business)
    }
}

// Subview chịu trách nhiệm chạy @Query
struct TripListView: View {
    @Query var trips: [Trip]
    
    // Khởi tạo Query linh hoạt (Dynamic Query) như được nhắc trong video
    init(filterType: TripFilterType, searchText: String) {
        let text = searchText // Biến cục bộ để dùng trong #Predicate
        
        // Tùy theo lựa chọn mà chúng ta build Predicate tương ứng
        // Sử dụng toán tử `is` để kiểm tra Subclass
        let predicate: Predicate<Trip>
        
        switch filterType {
        case .all:
            predicate = #Predicate<Trip> { trip in
                text.isEmpty || trip.destination.contains(text)
            }
        case .personal:
            predicate = #Predicate<Trip> { trip in
                (text.isEmpty || trip.destination.contains(text)) && (trip is PersonalTrip)
            }
        case .business:
            predicate = #Predicate<Trip> { trip in
                (text.isEmpty || trip.destination.contains(text)) && (trip is BusinessTrip)
            }
        }
        
        // Cập nhật lại query với predicate và sắp xếp theo ngày bắt đầu
        _trips = Query(filter: predicate, sort: \Trip.startDate)
    }
    
    var body: some View {
        if trips.isEmpty {
            ContentUnavailableView("Không tìm thấy chuyến đi", systemImage: "airplane")
        } else {
            List(trips) { trip in
                VStack(alignment: .leading, spacing: 5) {
                    Text(trip.destination)
                        .font(.headline)
                    
                    // Downcast để hiển thị thông tin đặc thù của Subclass
                    if let personalTrip = trip as? PersonalTrip {
                        Text("Mục đích: \(personalTrip.reason.rawValue)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    } else if let businessTrip = trip as? BusinessTrip {
                        Text("Công tác phí: \(Int(businessTrip.perDiem))đ/ngày")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
}
