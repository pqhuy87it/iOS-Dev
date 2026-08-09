import SwiftUI

/// A custom Layout for a step: diagram on top, then title, then subtitle.
/// The diagram's height depends on the subtitle's measured height — but instead
/// of measuring in onGeometryChange and triggering a second layout pass (which
/// hurts scrolling), we compute everything in ONE layout pass.
///
/// Order of subviews: [diagram, title, subtitle].
struct StepLayout: Layout {
    var spacing: CGFloat = 8
    var minDiagramHeight: CGFloat = 160

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else {
            return fallbackSize(proposal: proposal, subviews: subviews)
        }
        let width = proposal.width ?? 320
        let titleH = subviews[1].sizeThatFits(.init(width: width, height: nil)).height
        let subtitleH = subviews[2].sizeThatFits(.init(width: width, height: nil)).height
        // Diagram gets more height when the subtitle is short — decided here,
        // in one pass, no feedback loop.
        let diagramH = max(minDiagramHeight, 240 - subtitleH)
        let total = diagramH + spacing + titleH + spacing + subtitleH
        return CGSize(width: width, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else {
            placeFallback(in: bounds, subviews: subviews); return
        }
        let width = bounds.width
        let titleH = subviews[1].sizeThatFits(.init(width: width, height: nil)).height
        let subtitleH = subviews[2].sizeThatFits(.init(width: width, height: nil)).height
        let diagramH = max(minDiagramHeight, 240 - subtitleH)

        var y = bounds.minY
        subviews[0].place(at: CGPoint(x: bounds.minX, y: y),
                          proposal: .init(width: width, height: diagramH))
        y += diagramH + spacing
        subviews[1].place(at: CGPoint(x: bounds.minX, y: y),
                          proposal: .init(width: width, height: titleH))
        y += titleH + spacing
        subviews[2].place(at: CGPoint(x: bounds.minX, y: y),
                          proposal: .init(width: width, height: subtitleH))
    }

    // Fallbacks keep things safe if the subview count isn't exactly 3.
    private func fallbackSize(proposal: ProposedViewSize, subviews: Subviews) -> CGSize {
        var height: CGFloat = 0
        let width = proposal.width ?? 320
        for (i, s) in subviews.enumerated() {
            height += s.sizeThatFits(.init(width: width, height: nil)).height
            if i < subviews.count - 1 { height += spacing }
        }
        return CGSize(width: width, height: height)
    }

    private func placeFallback(in bounds: CGRect, subviews: Subviews) {
        var y = bounds.minY
        for s in subviews {
            let h = s.sizeThatFits(.init(width: bounds.width, height: nil)).height
            s.place(at: CGPoint(x: bounds.minX, y: y),
                    proposal: .init(width: bounds.width, height: h))
            y += h + spacing
        }
    }
}
