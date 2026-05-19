import SwiftUI

extension CGRect {
    var maxX: CGFloat {
        get { minX + width }
        set { origin.x = newValue - width }
    }
}

extension Layout.Subviews.Element {
    func hFlexibility(height: CGFloat? = nil) -> CGFloat {
        sizeThatFits(.init(width: CGFloat.greatestFiniteMagnitude,
                           height: height)).width - sizeThatFits(.init(width: 0,
                                                                       height: height)).width
    }
}

struct BarLayout: Layout {
    func proposeToLabels(label1: LayoutSubview,
                         label2: LayoutSubview,
                         proposal: ProposedViewSize) -> (CGSize, CGSize)
    {
        var remainingWidth = proposal.width
        let label1Size = label1.sizeThatFits(.init(width: remainingWidth.map { $0 / 2 },
                                                   height: proposal.height))
        remainingWidth = remainingWidth.map { $0 - label1Size.width }
        
        let label2Size = label2.sizeThatFits(.init(width: remainingWidth,
                                                   height: proposal.height))
        return (label1Size, label2Size)
    }

    func computeFrames(at startingPoint: CGPoint,
                       proposal: ProposedViewSize,
                       subviews: Subviews) -> [CGRect]
    {
        assert(subviews.count == 3)
        _ = proposal.width
        var remainingHeight = proposal.height
        let barSize = subviews[2].sizeThatFits(proposal)
        let flexibilities = [subviews[0].hFlexibility(), subviews[1].hFlexibility()]
        remainingHeight = remainingHeight.map { $0 - barSize.height }
        let priorities = subviews.map { $0.priority }
        let label1Size: CGSize
        let label2Size: CGSize
        // todo priority the other way around as well
        if priorities[0] > priorities[1] {
            let minWidth = subviews[1].sizeThatFits(.init(width: 0,
                                                          height: proposal.height)).width
            var remainingWidth = proposal.width

            label1Size = subviews[0].sizeThatFits(.init(width: remainingWidth.map { $0 - minWidth },
                                                        height: proposal.height))
            remainingWidth = remainingWidth.map { $0 - label1Size.width }
            label2Size = subviews[1].sizeThatFits(.init(width: remainingWidth,
                                                        height: proposal.height))
        } else if flexibilities[0] < flexibilities[1] {
            (label1Size, label2Size) = proposeToLabels(label1: subviews[0],
                                                       label2: subviews[1],
                                                       proposal: .init(width: proposal.width,
                                                                       height: remainingHeight))
        } else {
            (label2Size, label1Size) = proposeToLabels(label1: subviews[1],
                                                       label2: subviews[0],
                                                       proposal: .init(width: proposal.width, height: remainingHeight))
        }
        var currentPoint = startingPoint
        let label1Frame = CGRect(origin: currentPoint,
                                 size: label1Size)
        currentPoint.x += label1Size.width

        var label2Frame = CGRect(origin: currentPoint, size: label2Size)
        currentPoint.x = startingPoint.x
        currentPoint.y = max(label1Frame.maxY, label2Frame.maxY)

        let barFrame = CGRect(origin: currentPoint, size: barSize)
        label2Frame.maxX = max(barFrame.maxX, label2Frame.maxX)

        return [label1Frame, label2Frame, barFrame]
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
        print(frames)

        for (view, frame) in zip(subviews, frames) {
            view.place(at: frame.origin, proposal: .init(frame.size))
        }
    }
}

struct ContentView: View {
    @State private var width: CGFloat = 200
    @State private var barWidth: CGFloat = 0.8
    var body: some View {
        VStack {
            Slider(value: $width, in: 0 ... 350)
            Slider(value: $barWidth, in: 0 ... 1)
            BarLayout {
                Text("Leading Label")
                    .layoutPriority(1)
                    .border(.yellow)
                Text("Trailing Label")
                    .frame(minWidth: 30)
                Color.red
                    .frame(height: 8)
                    .frame(width: barWidth * width) // todo
            }
            .border(.blue)
            .frame(width: width, alignment: .leading)
            .border(.green)
            .padding()
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 300)
}
