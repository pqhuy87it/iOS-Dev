import SwiftUI

// MARK: - Domain models

enum DetailLevel: Int, CaseIterable, Identifiable, Comparable {
    case essential, standard, detailed
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .essential: "Essential"
        case .standard:  "Standard"
        case .detailed:  "Detailed"
        }
    }
    static func < (lhs: DetailLevel, rhs: DetailLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct Step: Identifiable, Hashable {
    let id: Int
    let title: String
    let subtitle: String
    let detailLevel: DetailLevel
    let hue: Double   // stand-in for a real diagram image
}

struct Photo: Identifiable, Hashable {
    let id: Int
    let hue: Double
}

// Sample data ------------------------------------------------------------

enum SampleData {
    static let steps: [Step] = (0..<300).map { i in
        Step(
            id: i,
            title: "Step \(i + 1)",
            subtitle: subtitles[i % subtitles.count],
            detailLevel: DetailLevel.allCases[i % DetailLevel.allCases.count],
            hue: Double(i % 20) / 20.0
        )
    }

    static let photos: [Photo] = (0..<40).map {
        Photo(id: $0, hue: Double($0 % 12) / 12.0)
    }

    private static let subtitles = [
        "Fold the top corner down to meet the base.",
        "Crease firmly, then unfold to leave a guide line.",
        "Reverse-fold both flaps inward along the marked lines.",
        "Rotate the model 90° and repeat on the opposite side.",
        "Tuck the loose edge into the pocket you just formed."
    ]
}

// MARK: - Async loaders (mock work to show prefetch benefits)

@Observable
final class DiagramLoader {
    let id: Int
    private(set) var isReady = false

    init(id: Int) {
        self.id = id
        // In init so the lazy stack's prefetch phase can start this early,
        // rather than waiting for onAppear.
    }

    @MainActor
    func load() async {
        // Simulate decoding/generating a diagram off the main path.
        try? await Task.sleep(for: .milliseconds(40))
        isReady = true
    }
}

/// A pager whose state must survive being scrolled off screen, so it lives in
/// the parent view (Showcase), not inside each PageView.
@Observable
final class ShowcasePager {
    private(set) var photos: [Photo] = Array(SampleData.photos.prefix(12))
    private(set) var atEnd = false
    private var isLoading = false

    @MainActor
    func fetchNextPage() async {
        guard !isLoading, !atEnd else { return }
        isLoading = true
        defer { isLoading = false }
        try? await Task.sleep(for: .milliseconds(300))
        let next = photos.count
        let more = SampleData.photos[safe: next ..< next + 12]
        photos.append(contentsOf: more)
        if photos.count >= SampleData.photos.count { atEnd = true }
    }
}

private extension Array {
    subscript(safe range: Range<Int>) -> ArraySlice<Element> {
        let lower = Swift.min(range.lowerBound, count)
        let upper = Swift.min(range.upperBound, count)
        return self[lower..<upper]
    }
}
