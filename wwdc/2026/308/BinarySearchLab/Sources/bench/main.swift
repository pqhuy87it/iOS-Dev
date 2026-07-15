import Foundation
import BinarySearchLab

// Simple command-line runner so you can see the speedup progression without
// Xcode. On real hardware, use Instruments (see README) for the deep analysis.

print("Building dataset…")
let data = SearchData()   // ~1 MiB array, 10k queries
print("Array elements: \(data.arrayCount), queries: \(data.queries.count)\n")

var results: [(String, Double)] = []

results.append(("1. Collection", measureThroughput(name: "Collection") {
    for q in data.queries { _ = binarySearchCollection(needle: q, haystack: data.sortedArray) }
}))

data.sortedArray.withUnsafeBufferPointer { buf in
    let span = buf.span
    results.append(("2. Span", measureThroughput(name: "Span") {
        for q in data.queries { _ = binarySearchSpan(needle: q, haystack: span) }
    }))
    results.append(("3. Span<Int>", measureThroughput(name: "Span<Int>") {
        for q in data.queries { _ = binarySearchInt(needle: q, haystack: span) }
    }))
    results.append(("4. Branchless", measureThroughput(name: "Branchless") {
        for q in data.queries { _ = binarySearchBranchless(needle: q, haystack: span) }
    }))
}

data.eytzingerArray.withUnsafeBufferPointer { buf in
    let span = buf.span
    results.append(("5. Eytzinger", measureThroughput(name: "Eytzinger") {
        for q in data.queries { _ = binarySearchEytzinger(needle: q, haystack: span) }
    }))
}

let baseline = results.first!.1
func pad(_ s: String, _ n: Int) -> String {
    s.count >= n ? s : s + String(repeating: " ", count: n - s.count)
}
print("\(pad("Version", 16)) \(pad("ops/s", 14)) speedup")
print(String(repeating: "-", count: 42))
for (name, ops) in results {
    let speed = String(format: "%.1fx", ops / baseline)
    print("\(pad(name, 16)) \(pad(String(Int(ops)), 14)) \(speed)")
}
