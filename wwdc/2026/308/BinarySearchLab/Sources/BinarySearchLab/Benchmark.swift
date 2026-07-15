import Foundation
import OSLog

// Signposter so Instruments (Points of Interest track) can zoom into exactly the
// region being optimized. This mirrors the session's harness.
public let signposter = OSSignposter(
    subsystem: "com.example.BinarySearchLab",
    category: .pointsOfInterest
)

/// Runs `body` repeatedly for `duration` and reports searches-per-second.
/// Uses ContinuousClock (monotonic, low-overhead) rather than Date.
@discardableResult
public func measureThroughput(
    name: StaticString,
    duration: Duration = .seconds(1),
    _ body: () -> Void
) -> Double {
    let interval = signposter.beginInterval(name)
    let start = ContinuousClock.now
    var iterations = 0
    var now = start

    repeat {
        body()
        iterations += 1
        now = .now
    } while start.duration(to: now) < duration

    let elapsed = start.duration(to: now)
    let seconds = Double(elapsed.components.seconds)
        + Double(elapsed.components.attoseconds) / 1e18
    let throughput = Double(iterations) / seconds

    signposter.endInterval(name, interval, "\(throughput) ops/s")
    return throughput
}

// MARK: - Shared test data

public struct SearchData {
    public let arrayCount: Int
    public let sortedArray: [Int]
    public let eytzingerArray: [Int]
    public let queries: [Int]

    /// - Parameters:
    ///   - sizeInBytes: total size of the searched array (8 MiB in the session,
    ///     scaled down here so it runs fast in a sandbox).
    ///   - queryCount: how many lookups per outer iteration.
    public init(sizeInBytes: Int = 1 << 20, queryCount: Int = 10_000) {
        let count = sizeInBytes / MemoryLayout<Int>.size
        self.arrayCount = count

        let sorted = (0..<count).map { _ in Int.random(in: 0..<count) }.sorted()
        self.sortedArray = sorted
        self.eytzingerArray = EytzingerArray.build(from: sorted)
        // Query for values known to exist, like the session does.
        self.queries = (0..<queryCount).map { _ in sorted.randomElement()! }
    }
}
