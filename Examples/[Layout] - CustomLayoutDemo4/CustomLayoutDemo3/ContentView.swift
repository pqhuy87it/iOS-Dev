import SwiftUI

// 1. Thay đổi maxX thành customMaxY để set lại origin.y giúp kéo giãn view theo chiều dọc
extension CGRect {
    var customMaxY: CGFloat {
        get { minY + height }
        set { origin.y = newValue - height }
    }
}

extension CGSize {
    init(_ dim: ViewDimensions) {
        self.init(width: dim.width, height: dim.height)
    }
}

// 2. Thay hFlexibility thành vFlexibility để đo độ linh hoạt theo chiều cao
extension Layout.Subviews.Element {
    func vFlexibility(width: CGFloat? = nil) -> CGFloat {
        sizeThatFits(.init(width: width,
                           height: CGFloat.greatestFiniteMagnitude)).height -
        sizeThatFits(.init(width: width,
                           height: 0)).height
    }
}

// 3. Layout mới theo chiều dọc
struct VerticalBarLayout: Layout {
    // Dùng HorizontalAlignment do các Label xếp theo cột dọc
    var alignment: HorizontalAlignment = .center

    init(alignment: HorizontalAlignment = .center) {
        self.alignment = alignment
    }

    func proposeToLabels(label1: LayoutSubview,
                         label2: LayoutSubview,
                         proposal: ProposedViewSize) -> (ViewDimensions, ViewDimensions)
    {
        var remainingHeight = proposal.height
        
        // Chia đôi chiều cao (thay vì width như bản gốc)
        let label1Size = label1.dimensions(in: .init(width: proposal.width,
                                                     height: remainingHeight.map { $0 / 2 }))
        remainingHeight = remainingHeight.map { $0 - label1Size.height }

        let label2Size = label2.dimensions(in: .init(width: proposal.width,
                                                     height: remainingHeight))
        return (label1Size, label2Size)
    }

    func computeFrames(at startingPoint: CGPoint,
                       proposal: ProposedViewSize,
                       subviews: Subviews) -> [CGRect]
    {
        assert(subviews.count == 3)
        var remainingWidth = proposal.width
        let barSize = subviews[2].sizeThatFits(proposal)
        
        // Tính toán độ ưu tiên và co dãn theo chiều dọc
        let flexibilities = [subviews[0].vFlexibility(), subviews[1].vFlexibility()]
        remainingWidth = remainingWidth.map { $0 - barSize.width }
        
        let priorities = subviews.map { $0.priority }
        let label1Size: ViewDimensions
        let label2Size: ViewDimensions
        
        // Tính toán kích thước (đổi width thành height)
        if priorities[0] > priorities[1] {
            let minHeight = subviews[1].dimensions(in: .init(width: proposal.width,
                                                             height: 0)).height
            var remainingHeight = proposal.height
            label1Size = subviews[0].dimensions(in: .init(width: proposal.width,
                                                          height: remainingHeight.map { $0 - minHeight }))
            remainingHeight = remainingHeight.map { $0 - label1Size.height }
            label2Size = subviews[1].dimensions(in: .init(width: proposal.width,
                                                          height: remainingHeight))
        } else if flexibilities[0] < flexibilities[1] {
            (label1Size, label2Size) = proposeToLabels(label1: subviews[0],
                                                       label2: subviews[1],
                                                       proposal: .init(width: remainingWidth,
                                                                       height: proposal.height))
        } else {
            (label2Size, label1Size) = proposeToLabels(label1: subviews[1],
                                                       label2: subviews[0],
                                                       proposal: .init(width: remainingWidth,
                                                                       height: proposal.height))
        }
        
        // Căn chỉnh (Alignment) theo trục X
        let label1X = label1Size[alignment]
        let label2X = label2Size[alignment]
        
        var currentPoint = startingPoint
        
        // Sắp xếp Label 1 (Top)
        let label1Frame = CGRect(origin: .init(x: currentPoint.x + (label2X - label1X),
                                               y: currentPoint.y),
                                 size: CGSize(label1Size))
        
        // Di chuyển điểm Y xuống để vẽ Label 2 (Bottom)
        currentPoint.y += label1Size.height
        var label2Frame = CGRect(origin: currentPoint, size: CGSize(label2Size))
        
        // Sắp xếp Bar (Nằm bên phải các Label)
        currentPoint.y = startingPoint.y
        currentPoint.x = max(label1Frame.maxX, label2Frame.maxX)
        let barFrame = CGRect(origin: currentPoint, size: barSize)
        
        // Kéo dài phần bottom của Label 2 xuống bằng với đuôi của Bar
        label2Frame.customMaxY = max(barFrame.maxY, label2Frame.maxY)
        
        let frames = [label1Frame, label2Frame, barFrame]
        
        // Offset để căn lề nếu có Label bị lệch âm
        let minX = frames.map { $0.minX }.min() ?? startingPoint.x
        let offset = minX - startingPoint.x

        return frames.map {
            $0.offsetBy(dx: -offset, dy: 0)
        }
    }

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache _: inout ()) -> CGSize
    {
        let frames = computeFrames(at: .zero,
                                   proposal: proposal,
                                   subviews: subviews)
        return frames.reduce(CGRect.null) { $0.union($1) }.size
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache _: inout ())
    {
        let frames = computeFrames(at: bounds.origin,
                                   proposal: proposal,
                                   subviews: subviews)

        for (view, frame) in zip(subviews, frames) {
            view.place(at: frame.origin, proposal: .init(frame.size))
        }
    }
}

// 4. View Thực Hành
struct ContentView: View {
    @State private var layoutHeight: CGFloat = 300
    @State private var barHeightRatio: CGFloat = 0.8
    
    var body: some View {
        VStack(spacing: 30) {
            
            // Bảng điều khiển
            VStack {
                Text("Điều chỉnh chiều cao tổng (Height)")
                Slider(value: $layoutHeight, in: 100 ... 500)
                
                Text("Điều chỉnh tỷ lệ thanh Bar")
                Slider(value: $barHeightRatio, in: 0 ... 1)
            }
            .padding()
            
            // Khu vực Layout Dọc
            VerticalBarLayout(alignment: .leading) {
                Text("Top Label")
                    .layoutPriority(1)
                    .border(.yellow)
                
                Text("Bottom Label")
                    .font(.largeTitle)
                    .frame(minHeight: 30) // Đổi từ minWidth sang minHeight
                
                // Thanh Bar đổi qua quản lý bằng Width cứng và tính toán Height mềm
                Color.red
                    .frame(width: 8)
                    .frame(height: barHeightRatio * layoutHeight)
            }
            .border(.blue)
            // Căn chỉnh Frame hiển thị theo Top
            .frame(width: 250, height: layoutHeight, alignment: .top)
            .border(.green)
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
