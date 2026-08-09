import SwiftUI

struct ContentView: View {
    @State private var settings = DemoSettings()
    @State private var scrollPosition = ScrollPosition()
    @State private var showScrollButton = false

    // Data-level filtering (GOOD): the ForEach only ever sees the steps that
    // should be visible, so the lazy stack keeps a static subview count.
    private var visibleSteps: [Step] {
        if settings.filterAtDataLevel {
            SampleData.steps.filter { $0.detailLevel <= settings.detailLevel }
        } else {
            SampleData.steps   // all steps; StepView decides via a conditional (BAD)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    ForEach(visibleSteps) { step in
                        // When NOT filtering at the data level, we emulate the
                        // anti-pattern: a conditional inside the leaf view that
                        // changes the number of produced subviews.
                        if settings.filterAtDataLevel
                            || step.detailLevel <= settings.detailLevel {
                            StepView(step: step)
                        }
                    }
                    ShowcaseSection()
                }
            }
            .scrollPosition($scrollPosition)
            // GOOD: react to which IDs are visible rather than an absolute offset.
            .onScrollTargetVisibilityChange(idType: Step.ID.self, threshold: 0.6) { visibleIDs in
                // Show the jump button once we've scrolled past the first steps.
                showScrollButton = !(visibleIDs.contains(SampleData.steps.first?.id ?? -1))
            }
            .overlay(alignment: .bottom) { scrollButton }
            .navigationTitle("Origami")
            .toolbar { settingsMenu }
            .environment(settings)
        }
    }

    // MARK: - Programmatic scrolling

    @ViewBuilder
    private var scrollButton: some View {
        if showScrollButton {
            Button {
                withAnimation { scrollPosition.scrollTo(id: "showcase-header") }
            } label: {
                Label("Jump to Showcase", systemImage: "arrow.down.circle.fill")
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Toggle the good/bad patterns live

    @ToolbarContentBuilder
    private var settingsMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            @Bindable var s = settings
            Menu {
                Picker("Detail level", selection: $s.detailLevel) {
                    ForEach(DetailLevel.allCases) { Text($0.label).tag($0) }
                }
                Divider()
                Toggle("Filter at data level", isOn: $s.filterAtDataLevel)
                Toggle("Set up in init", isOn: $s.setUpInInit)
                Toggle("Custom layout (vs onGeometryChange)", isOn: $s.useCustomLayout)
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
        }
    }
}

#Preview {
    ContentView()
}
