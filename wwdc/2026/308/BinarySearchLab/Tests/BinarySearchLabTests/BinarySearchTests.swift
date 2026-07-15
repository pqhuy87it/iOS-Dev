import Testing
import Foundation
@testable import BinarySearchLab

// A shared dataset for all tests. Built once.
private let data = SearchData()

// MARK: - Correctness
//
// Every optimized version must agree with the standard library on where an
// element lives before we trust its speed. Correctness first, then throughput.

@Suite("Correctness")
struct CorrectnessTests {

    @Test func collectionMatchesStdlib() {
        for q in data.queries.prefix(200) {
            let expected = data.sortedArray.firstIndex(of: q)!
            let got = binarySearchCollection(needle: q, haystack: data.sortedArray)
            // Duplicates may exist; just require we landed on a matching value.
            #expect(data.sortedArray[got] == data.sortedArray[expected])
        }
    }

    @Test func spanMatchesStdlib() {
        data.sortedArray.withUnsafeBufferPointer { buf in
            let span = buf.span
            for q in data.queries.prefix(200) {
                let got = binarySearchSpan(needle: q, haystack: span)
                #expect(span[got] == q)
            }
        }
    }

    @Test func intMatchesStdlib() {
        data.sortedArray.withUnsafeBufferPointer { buf in
            let span = buf.span
            for q in data.queries.prefix(200) {
                let got = binarySearchInt(needle: q, haystack: span)
                #expect(span[got] == q)
            }
        }
    }

    @Test func branchlessMatchesStdlib() {
        data.sortedArray.withUnsafeBufferPointer { buf in
            let span = buf.span
            for q in data.queries.prefix(200) {
                let got = binarySearchBranchless(needle: q, haystack: span)
                #expect(span[got] == q)
            }
        }
    }

    @Test func eytzingerFindsExistingValues() {
        data.eytzingerArray.withUnsafeBufferPointer { buf in
            let span = buf.span
            for q in data.queries.prefix(200) {
                let got = binarySearchEytzinger(needle: q, haystack: span)
                #expect(got >= 1 && got < span.count)
                #expect(span[got] == q)
            }
        }
    }
}

// MARK: - Throughput benchmarks
//
// Profile these with Instruments:
//   1. CPU Profiler   → run `throughput_1_collection` and `throughput_2_span`,
//                       compare, and inspect the Collection call tree.
//   2. Processor Trace→ run `processorTrace_span` (few iterations) on M4/A18.
//   3. CPU Counters   → run the later versions in bottleneck-analysis mode.
//
// In Xcode: right-click a test in the Test navigator → "Profile".

@Suite("Throughput")
struct ThroughputTests {

    @Test func throughput_1_collection() {
        let t = measureThroughput(name: "Collection") {
            for q in data.queries {
                _ = binarySearchCollection(needle: q, haystack: data.sortedArray)
            }
        }
        print("Collection:  \(Int(t)) ops/s")
    }

    @Test func throughput_2_span() {
        data.sortedArray.withUnsafeBufferPointer { buf in
            let span = buf.span
            let t = measureThroughput(name: "Span") {
                for q in data.queries {
                    _ = binarySearchSpan(needle: q, haystack: span)
                }
            }
            print("Span:        \(Int(t)) ops/s")
        }
    }

    @Test func throughput_3_int() {
        data.sortedArray.withUnsafeBufferPointer { buf in
            let span = buf.span
            let t = measureThroughput(name: "Span<Int>") {
                for q in data.queries {
                    _ = binarySearchInt(needle: q, haystack: span)
                }
            }
            print("Span<Int>:   \(Int(t)) ops/s")
        }
    }

    @Test func throughput_4_branchless() {
        data.sortedArray.withUnsafeBufferPointer { buf in
            let span = buf.span
            let t = measureThroughput(name: "Branchless") {
                for q in data.queries {
                    _ = binarySearchBranchless(needle: q, haystack: span)
                }
            }
            print("Branchless:  \(Int(t)) ops/s")
        }
    }

    @Test func throughput_5_eytzinger() {
        data.eytzingerArray.withUnsafeBufferPointer { buf in
            let span = buf.span
            let t = measureThroughput(name: "Eytzinger") {
                for q in data.queries {
                    _ = binarySearchEytzinger(needle: q, haystack: span)
                }
            }
            print("Eytzinger:   \(Int(t)) ops/s")
        }
    }

    /// Short run designed for Processor Trace — only a handful of iterations, so
    /// the trace stays small and you can see every instruction of a single call.
    @Test func processorTrace_span() {
        data.sortedArray.withUnsafeBufferPointer { buf in
            let span = buf.span
            signposter.withIntervalSignpost("ProcessorTrace") {
                for q in data.queries.prefix(10) {
                    _ = binarySearchSpan(needle: q, haystack: span)
                }
            }
        }
    }
}
