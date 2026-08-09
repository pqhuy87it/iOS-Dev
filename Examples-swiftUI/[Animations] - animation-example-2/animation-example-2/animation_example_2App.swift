import SwiftUI

@main
struct animation_example_2App: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    NavigationLink("Basic Animations") {
                        AnimationContentView()
                            .navigationTitle("Basic Animations")
                    }

                    NavigationLink("Liquid Glass Effect") {
                        LiquidGlassPlayground()
                            .navigationTitle("Liquid Glass Effect")
                    }

                    NavigationLink("Phase Animator") {
                        OpencodeTypingPlayground()
                            .navigationTitle("Phase Animator")
                    }

                    NavigationLink("Symbol & Text Effects") {
                        ThinkingPlayground()
                            .navigationTitle("Symbol & Text Effects")
                    }

                    NavigationLink("Core Animation (CABasicAnimation + CAMediaTiming)") {
                        AnimationDemoView()
                            .navigationTitle("Core Animation (CABasicAnimation + CAMediaTiming)")
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Animation Demo")
                .preferredColorScheme(.dark)
            }
        }
    }
}
