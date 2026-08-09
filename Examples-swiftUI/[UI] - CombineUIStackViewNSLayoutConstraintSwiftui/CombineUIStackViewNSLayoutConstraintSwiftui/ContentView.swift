import SwiftUI

// MARK: - Model (tương đương ListElement.h/.m)
struct ListElement: Identifiable {
    let id = UUID()
    let title: String
    let data: String
}

// MARK: - Sample Data (tương đương SampleData.m)
enum SampleData {
    static let items: [ListElement] = [
        ListElement(title: "MSRP", data: "$184,900"),
        ListElement(title: "EPA Clasification", data: "Two-Seaters"),
        ListElement(title: "Engine", data: "Twin Turbo Premium Unleaded V-8 3.8L/232 cu in"),
        ListElement(title: "Transmission", data: "Auto-Shift Manual w/OD"),
        ListElement(title: "Drivetrain", data: "Rear Wheel Drive"),
        ListElement(title: "Fuel", data: "Gasoline"),
        ListElement(title: "Seating", data: "2"),
        ListElement(title: "Horsepower", data: "710"),
        ListElement(title: "Brakes", data: "4-Wheel Disc Brakes"),
        ListElement(title: "Front Tire Size", data: "P225/35YR19"),
        ListElement(title: "Rear Tire Size", data: "P285/35YR20"),
        ListElement(title: "EPA - City MPG", data: "16"),
        ListElement(title: "EPA - Highway MPG", data: "23"),
        ListElement(title: "EPA - Combined MPG", data: "19"),
    ]
}

// MARK: - Row (tương đương MyListRow.m)
// Hàng ngang: title bên trái, data bên phải, chia đều (giống distribution = FillEqually)
struct MyListRow: View {
    let element: ListElement

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(element.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading) // chia đều nửa trái

            Text(element.data)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(white: 0.2))
                .frame(maxWidth: .infinity, alignment: .leading) // chia đều nửa phải
        }
        .padding(.vertical, 12) // vertical padding giống constraint top/bottom = 12
    }
}

// MARK: - List Component (tương đương MyListViewController.m)
// Đây là phần có hiệu ứng đóng/mở
struct MyListView: View {
    let elements: [ListElement]

    // Số dòng hiển thị khi collapse. UIKit dùng "row thứ 3" (arrangedSubviews[2]) → 3 dòng
    private let collapsedCount = 3

    @State private var isExpanded = false

    // Danh sách dòng đang hiển thị tùy theo trạng thái
    private var visibleElements: ArraySlice<ListElement> {
        isExpanded ? elements[...] : elements.prefix(collapsedCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title (tương đương titleLabel nền cyan)
            Text("Details - tap anywhere to expand/collapse")
                .font(.system(size: 16, weight: .bold))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.cyan)

            // Container trắng chứa các dòng, clip phần thừa (giống clipsToBounds = YES)
            VStack(spacing: 0) {
                ForEach(Array(visibleElements.enumerated()), id: \.element.id) { index, element in
                    MyListRow(element: element)
                    // Đường kẻ phân cách (giống separator lines trong UIKit)
                    Rectangle()
                        .fill(Color(white: 0.9))
                        .frame(height: 1)
                }
            }
            .background(.white)
            .clipped() // tương đương clipsToBounds
        }
        .padding(.horizontal, 12)
        .background(Color(.systemGreen)) // nền xanh lá giống MyListViewController
        .contentShape(Rectangle()) // để tap được cả vùng trống
        .onTapGesture {
            // Toàn bộ "magic" nằm ở đây: đổi state trong withAnimation.
            // SwiftUI tự tính lại layout và animate — không cần constraint tranh chấp priority
            withAnimation(.easeInOut(duration: 0.5)) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - Top Component (tương đương MyTopViewController.m)
struct MyTopView: View {
    var body: some View {
        Text("This is the text in the label in MyTopViewController.\n\nYou might replace this with a horizontal collection view of images, for example.")
            .font(.system(size: 18))
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.95))
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemRed))
    }
}

// MARK: - Bottom Component (tương đương MyBottomViewController.m)
struct MyBottomView: View {
    var body: some View {
        Text("Striking styling, incredible acceleration and handling, exclusivity, relatively inexpensive for a true exotic.\n\nThe McLaren 570S is a brand new model from McLaren, slotting into the bottom of their lineup below the 650S. The car represents a small move towards the mainstream for the bespoke manufacturer of supercars. Everything that's true for other McLarens remains true for the 570S. However, performance is incredible and buyers who decide to use their cars on a race track will be rewarded with extremely fast lap times.")
            .font(.system(size: 15).italic())
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.95))
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBlue))
    }
}

// MARK: - Details (tương đương DetailsViewController.m)
// ScrollView dọc chứa các component xếp chồng (giống mainStackView trong scrollView)
struct DetailsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MyListView(elements: SampleData.items)
                MyTopView()
                MyListView(elements: SampleData.items)
                MyBottomView()
                MyListView(elements: SampleData.items)
            }
        }
        .background(Color(.systemYellow)) // nền vàng giống scrollView
        .navigationTitle("Details")
    }
}

// MARK: - Root (tương đương ViewController.m + disclaimer alert)
struct ContentView: View {
    @State private var showDisclaimer = false

    var body: some View {
        NavigationStack {
            VStack {
                NavigationLink("Show Details") {
                    DetailsView()
                }
                .padding()
            }
            .navigationTitle("Scratch2021")
        }
        .onAppear {
            showDisclaimer = true // giống viewDidAppear + bFirstTime
        }
        .alert("Please Note", isPresented: $showDisclaimer) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This is Example Code Only and should not be considered \"Production Ready.\"")
        }
    }
}

#Preview {
    ContentView()
}
