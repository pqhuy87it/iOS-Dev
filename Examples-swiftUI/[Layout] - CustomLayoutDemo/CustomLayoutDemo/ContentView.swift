import SwiftUI

extension CGRect {
    var maxX: CGFloat {
        get { minX + width }
        set { origin.x = newValue - width }
    }
}

struct BarLayout: Layout {
    func computeFrames(at startingPoint: CGPoint, proposal: ProposedViewSize, subviews: Subviews) -> [CGRect] {
        assert(subviews.count == 3)
        let label1Size = subviews[0].sizeThatFits(proposal)
        let label2Size = subviews[1].sizeThatFits(proposal)
        let barSize = subviews[2].sizeThatFits(proposal)
        var currentPoint = startingPoint
        let label1Frame = CGRect(origin: currentPoint, size: label1Size)
        currentPoint.x += label1Size.width
        var label2Frame = CGRect(origin: currentPoint, size: label2Size)
        currentPoint.x = startingPoint.x
        currentPoint.y = max(label1Frame.maxY, label2Frame.maxY)
        let barFrame = CGRect(origin: currentPoint, size: barSize)
        label2Frame.maxX = max(barFrame.maxX, label2Frame.maxX)
        return [label1Frame, label2Frame, barFrame]
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = computeFrames(at: .zero, proposal: proposal, subviews: subviews)
        return frames.reduce(CGRect.null) { $0.union($1) }.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = self.computeFrames(at: bounds.origin, proposal: proposal, subviews: subviews)
        print(frames)
        for (view, frame) in zip(subviews, frames) {
            view.place(at: frame.origin, proposal: proposal)
        }
    }
}

struct ContentView: View {
    @State private var width: CGFloat = 200
    @State private var barWidth: CGFloat = 150
    var body: some View {
        VStack {
            Slider(value: $width, in: 0...350)
            Slider(value: $barWidth, in: 0...350)
            BarLayout {
                Text("Leading Label")
                Text("Trailing Label")
                Color.red
                    .frame(height: 8)
                    .frame(width: barWidth)
            }
            .border(.blue)
            .frame(width: width)
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
