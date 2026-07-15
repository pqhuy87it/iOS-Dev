import Foundation

// MARK: - Version 1: Generic over Collection (the slow starting point)
//
// This is where WWDC25 session 308 begins. It's clean and general, but the CPU
// Profiler shows a lot of time in Collection protocol witnesses, Array's
// copy-on-write checks, and generic overhead.

public func binarySearchCollection<E, C>(
    needle: E,
    haystack: C
) -> C.Index where E: Comparable, C: Collection<E> {
    var start = haystack.startIndex
    var length = haystack.count

    while length > 0 {
        let half = length / 2
        let middle = haystack.index(start, offsetBy: half)
        let middleValue = haystack[middle]
        if needle < middleValue {
            length = half
        } else if needle == middleValue {
            return middle
        } else {
            start = haystack.index(after: middle)
            length -= half + 1
        }
    }
    return start
}

// MARK: - Version 2: Span (Swift 6.2) — ~4x faster, algorithm unchanged
//
// Span is a base-address + count view over contiguous memory. Swapping the
// container type removes Array/generic overhead without touching the logic.

public func binarySearchSpan<E: Comparable>(
    needle: E,
    haystack: Span<E>
) -> Int {
    var start = 0
    var length = haystack.count

    while length > 0 {
        let half = length / 2
        let middle = start + half
        let middleValue = haystack[middle]
        if needle < middleValue {
            length = half
        } else if needle == middleValue {
            return middle
        } else {
            start = middle + 1
            length -= half + 1
        }
    }
    return start
}

// MARK: - Version 3: Manually specialized for Int — ~1.7x faster again
//
// Processor Trace revealed the real cost wasn't bounds checking but the
// unspecialized generic Comparable: protocol metadata + comparisons that can't
// inline. In a framework you'd use @inlinable; here we specialize by hand.

public func binarySearchInt(
    needle: Int,
    haystack: Span<Int>
) -> Int {
    var start = 0
    var length = haystack.count

    while length > 0 {
        let half = length / 2
        let middle = start + half
        let middleValue = haystack[middle]
        if needle < middleValue {
            length = half
        } else if needle == middleValue {
            return middle
        } else {
            start = middle + 1
            length -= half + 1
        }
    }
    return start
}

// MARK: - Version 4: Branchless — ~2x faster again
//
// CPU Counters (Discarded Sampling) showed the needle comparison is an
// essentially random branch that mispredicts constantly. Rewriting so the
// condition only *selects a value* lets the compiler emit a conditional move
// instead of a control-flow branch. `&+` uses unchecked arithmetic to avoid the
// overflow-trap branch. (This is the "fragile micro-optimization" the session
// warns about — less safe, harder to read.)

public func binarySearchBranchless(
    needle: Int,
    haystack: Span<Int>
) -> Int {
    var start = 0
    var length = haystack.count

    while length > 0 {
        let remainder = length % 2
        length /= 2
        let middle = start &+ length
        let middleValue = haystack[middle]
        if needle > middleValue {
            start = middle &+ remainder
        }
    }
    return start
}

// MARK: - Version 5: Eytzinger layout — ~2x faster again
//
// The final bottleneck is memory: classic binary search jumps around and misses
// the cache. Reordering the array as a breadth-first traversal of the search
// tree (Eytzinger layout) packs the early comparisons onto the same cache line.
//
// NOTE: the haystack here must ALREADY be in Eytzinger layout (1-indexed, with a
// dummy slot at index 0). Use `EytzingerArray` below to build it.

public func binarySearchEytzinger(
    needle: Int,
    haystack: Span<Int>
) -> Int {
    var index = 1
    let count = haystack.count

    while index < count {
        let value = haystack[index]
        index *= 2
        if value < needle {
            index += 1
        }
    }
    // Undo the trailing "went right past a leaf" steps to recover the position.
    return index >> ((~index).trailingZeroBitCount + 1)
}

// MARK: - Helper: build an Eytzinger-ordered array from a sorted array
//
// Result array is size n+1; slot 0 is unused (root lives at index 1).

public enum EytzingerArray {
    public static func build(from sorted: [Int]) -> [Int] {
        var result = [Int](repeating: 0, count: sorted.count + 1)
        var sourceIndex = 0
        reorder(sorted, into: &result, sourceIndex: &sourceIndex, resultIndex: 1)
        return result
    }

    private static func reorder(
        _ input: [Int],
        into array: inout [Int],
        sourceIndex: inout Int,
        resultIndex: Int
    ) {
        guard resultIndex < array.count else { return }
        reorder(input, into: &array, sourceIndex: &sourceIndex, resultIndex: 2 * resultIndex)
        array[resultIndex] = input[sourceIndex]
        sourceIndex += 1
        reorder(input, into: &array, sourceIndex: &sourceIndex, resultIndex: 2 * resultIndex + 1)
    }
}
