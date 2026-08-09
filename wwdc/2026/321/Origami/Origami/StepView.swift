import SwiftUI

// MARK: - Demo settings passed through the environment

@Observable
final class DemoSettings {
    var detailLevel: DetailLevel = .essential
    var filterAtDataLevel = true      // true = good, false = filter inside the view (bad)
    var setUpInInit = true            // true = good (init), false = onAppear (bad)
    var useCustomLayout = true        // true = StepLayout, false = onGeometryChange (bad)
    var highlighted: Set<Int> = []    // lifted state, survives scroll-off
}

// MARK: - StepView
//
// Shows both the recommended patterns and the anti-patterns from session 321,
// switchable via DemoSettings so you can feel the difference while scrolling.

struct StepView: View {
    let step: Step
    @Environment(DemoSettings.self) private var settings

    // GOOD: loader created in init → prefetch can start work before onAppear.
    // BAD:  loader left unconfigured and configured in onAppear (see below).
    @State private var loader: DiagramLoader
    // Tracks whether we've kicked off loading (used by the onAppear path).
    @State private var didConfigure = false

    init(step: Step) {
        self.step = step
        // Always allocate here, but only the GOOD path uses the id immediately.
        _loader = State(initialValue: DiagramLoader(id: step.id))
    }

    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(settings.highlighted.contains(step.id)
                          ? Color.yellow.opacity(0.25)
                          : Color(.secondarySystemBackground))
            )
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture { toggleHighlight() }
            .task {
                // GOOD path: start immediately (loader already knows its id).
                if settings.setUpInInit {
                    await loader.load()
                }
            }
            .onAppear {
                // BAD path: only begin work once the view is already on screen,
                // defeating the lazy stack's prefetch. Kept for comparison.
                if !settings.setUpInInit, !didConfigure {
                    didConfigure = true
                    Task { await loader.load() }
                }
            }
    }

    // The visual content, laid out two different ways for comparison.
    @ViewBuilder
    private var content: some View {
        if settings.useCustomLayout {
            // GOOD: one layout pass, no feedback loop.
            StepLayout {
                DiagramPlaceholder(hue: step.hue)
                    .opacity(loader.isReady ? 1 : 0.35)
                StepTitle(text: step.title)
                StepSubtitle(text: step.subtitle)
            }
        } else {
            // BAD: measure subtitle via onGeometryChange, then resize diagram →
            // extra layout pass every time a cell appears → janky scrolling.
            BadStepBody(step: step, isReady: loader.isReady)
        }
    }

    private func toggleHighlight() {
        if settings.highlighted.contains(step.id) {
            settings.highlighted.remove(step.id)
        } else {
            settings.highlighted.insert(step.id)
        }
    }
}

// The anti-pattern body: layout that reacts to measured geometry.
private struct BadStepBody: View {
    let step: Step
    let isReady: Bool
    @State private var subtitleHeight: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DiagramPlaceholder(hue: step.hue)
                .frame(height: max(160, 240 - (subtitleHeight ?? 0)))
                .opacity(isReady ? 1 : 0.35)
            StepTitle(text: step.title)
            StepSubtitle(text: step.subtitle)
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { _, value in
                    subtitleHeight = value   // triggers another layout pass
                }
        }
    }
}
