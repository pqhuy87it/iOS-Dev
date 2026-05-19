import SwiftUI

// MARK: - Custom ScrollTargetBehavior (Version 3: Robust Paging)
@available(iOS 17.0, *)
struct CustomHorizontalPagingBehavior: ScrollTargetBehavior {
    enum Direction {
        case left, right, none
    }
    
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let scrollViewWidth = context.containerSize.width
        let contentWidth = context.contentSize.width
        
        // Nếu nội dung nhỏ hơn ScrollView thì căn trái
        guard contentWidth > scrollViewWidth else {
            target.rect.origin.x = 0
            return
        }
        
        let originalOffset = context.originalTarget.rect.minX
        let targetOffset = target.rect.minX
        
        // Xác định hướng cuộn
        let direction: Direction = targetOffset > originalOffset ? .left : (targetOffset < originalOffset ? .right : .none)
        
        guard direction != .none else {
            target.rect.origin.x = originalOffset
            return
        }
        
        let thresholdRatio: CGFloat = 1 / 3
        let remaining: CGFloat = direction == .left ? (contentWidth - context.originalTarget.rect.maxX) : (context.originalTarget.rect.minX)
        let threshold = remaining <= scrollViewWidth ? remaining * thresholdRatio : scrollViewWidth * thresholdRatio
        
        let dragDistance = originalOffset - targetOffset
        var destination: CGFloat = originalOffset
        
        // Kiểm tra quãng đường kéo (drag) có vượt ngưỡng không
        if abs(dragDistance) > threshold {
            destination = dragDistance > 0 ? originalOffset - scrollViewWidth : originalOffset + scrollViewWidth
        } else {
            if direction == .right {
                destination = ceil(originalOffset / scrollViewWidth) * scrollViewWidth // Cuộn phải (trang lùi về)
            } else {
                destination = floor(originalOffset / scrollViewWidth) * scrollViewWidth // Cuộn trái (trang tiến tới)
            }
        }
        
        // Xử lý Boundary (Hai bên rìa của ScrollView)
        let maxOffset = contentWidth - scrollViewWidth
        let boundedDestination = min(max(destination, 0), maxOffset)
        
        if boundedDestination >= maxOffset * 0.95 {
            destination = maxOffset
        } else if boundedDestination <= scrollViewWidth * 0.05 {
            destination = 0
        } else {
            if direction == .right {
                let offsetFromRight = maxOffset - boundedDestination
                let pageFromRight = round(offsetFromRight / scrollViewWidth)
                destination = maxOffset - (pageFromRight * scrollViewWidth)
            } else {
                let pageNumber = round(boundedDestination / scrollViewWidth)
                destination = min(pageNumber * scrollViewWidth, maxOffset)
            }
        }
        
        target.rect.origin.x = destination
    }
}

// MARK: - Extension để gọi dễ dàng hơn
@available(iOS 17.0, *)
extension ScrollTargetBehavior where Self == CustomHorizontalPagingBehavior {
    static var horizontalPaging: CustomHorizontalPagingBehavior { .init() }
}

// MARK: - View Thực Hành
@available(iOS 17.0, *)
struct CustomPagingPracticeView: View {
    // Để fix lỗi misalignment khi xoay màn hình
    @Environment(\.verticalSizeClass) var sizeClass

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(0 ..< 10) { page in
                    VStack {
                        Text("Trang \(page)")
                            .font(.largeTitle)
                            .bold()
                        Text("Vuốt để cuộn trang")
                            .font(.subheadline)
                    }
                    // Test với 1/3 chiều rộng màn hình. Bạn có thể đổi `count` thành 1 để chiếm toàn màn hình
                    .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 0, alignment: .center)
                    .frame(height: 250)
                    .background(Color.blue.opacity(Double(page % 2 == 0 ? 0.3 : 0.6)))
                    .border(Color.red, width: 2)
                }
            }
        }
        .border(Color.blue, width: 2)
        // Áp dụng Custom Behavior
        .scrollTargetBehavior(.horizontalPaging)
        // Trigger render lại khi xoay thiết bị
        .id(sizeClass)
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        CustomPagingPracticeView()
    } else {
        Text("Yêu cầu iOS 17 trở lên")
    }
}
