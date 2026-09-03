import Foundation

typealias HTTPCode = Int
typealias HTTPCodes = Range<HTTPCode>

nonisolated extension HTTPCodes {
    static var success = 200 ..< 300
}
