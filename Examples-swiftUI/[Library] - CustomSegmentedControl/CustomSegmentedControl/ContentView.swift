import SwiftUI

// MARK: - Preference Key đo kích thước segment

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// View trong suốt đặt ở background để đọc kích thước của view cha qua GeometryReader.
struct BackgroundGeometryReader: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: SizePreferenceKey.self, value: geometry.size)
        }
    }
}

/// Modifier: gắn vào view nào thì view đó tự báo kích thước ra ngoài qua binding.
struct SizeAwareViewModifier: ViewModifier {
    @Binding var viewSize: CGSize

    func body(content: Content) -> some View {
        content
            .background(BackgroundGeometryReader())
            .onPreferenceChange(SizePreferenceKey.self) { newSize in
                if viewSize != newSize { viewSize = newSize }
            }
    }
}

// MARK: - Segmented Picker

struct SegmentedPicker: View {
    // Style constants
    private static let activeSegmentColor   = Color(.tertiarySystemBackground)
    private static let backgroundColor      = Color(.secondarySystemBackground)
    private static let shadowColor          = Color.black.opacity(0.2)
    private static let textColor            = Color(.secondaryLabel)
    private static let selectedTextColor    = Color(.label)

    private static let textFont: Font       = .system(size: 12)
    private static let cornerRadius: CGFloat = 12
    private static let shadowRadius: CGFloat = 4
    private static let segmentXPadding: CGFloat = 16
    private static let segmentYPadding: CGFloat = 8
    private static let pickerPadding: CGFloat = 4
    private static let animationDuration: Double = 0.2

    // Kích thước một segment, dùng để vẽ ô active
    @State private var segmentSize: CGSize = .zero

    @Binding private var selection: Int
    private let items: [String]

    init(items: [String], selection: Binding<Int>) {
        self.items = items
        self._selection = selection
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Ô active (chỉ hiện sau khi đã đo được kích thước)
            activeSegmentView

            HStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    segmentView(for: index)
                }
            }
        }
        .padding(Self.pickerPadding)
        .background(Self.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
    }

    // MARK: Ô active trượt theo lựa chọn

    @ViewBuilder
    private var activeSegmentView: some View {
        // Chưa đo xong thì chưa vẽ — tránh animation chạy ngay lúc init
        if segmentSize != .zero {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .foregroundColor(Self.activeSegmentColor)
                .shadow(color: Self.shadowColor, radius: Self.shadowRadius)
                .frame(width: segmentSize.width, height: segmentSize.height)
                .offset(x: activeSegmentHorizontalOffset(), y: 0)
                .animation(.linear(duration: Self.animationDuration), value: selection)
        }
    }

    // MARK: Từng segment

    @ViewBuilder
    private func segmentView(for index: Int) -> some View {
        let isSelected = selection == index
        Text(items[index])
            .font(Self.textFont)
            .foregroundColor(isSelected ? Self.selectedTextColor : Self.textColor)
            .lineLimit(1)
            .padding(.vertical, Self.segmentYPadding)
            .padding(.horizontal, Self.segmentXPadding)
            .frame(minWidth: 0, maxWidth: .infinity)
            .modifier(SizeAwareViewModifier(viewSize: $segmentSize))
            .contentShape(Rectangle())
            .onTapGesture { selection = index }
    }

    // MARK: Tính offset ngang cho ô active

    private func activeSegmentHorizontalOffset() -> CGFloat {
        CGFloat(selection) * segmentSize.width
    }
}

// MARK: - Preview

struct PreviewView: View {
    @State private var selection: Int = 0
    private let items = ["M", "T", "W", "T", "F"]

    var body: some View {
        VStack(spacing: 40) {
            SegmentedPicker(items: items, selection: $selection)
            Text("Đang chọn: \(items[selection]) (index \(selection))")
                .font(.headline)
        }
        .padding()
    }
}

#Preview {
    PreviewView()
}
