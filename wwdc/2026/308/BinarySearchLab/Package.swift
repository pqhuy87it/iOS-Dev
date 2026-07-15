// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BinarySearchLab",
    platforms: [
        // Span requires the Swift 6.2 toolchain / recent SDKs.
        // Processor Trace needs M4 / A18 hardware, but the code runs anywhere.
        .macOS(.v15), .iOS(.v18)
    ],
    targets: [
        .target(
            name: "BinarySearchLab",
            swiftSettings: [
                // Keep optimizations honest while experimenting.
                .unsafeFlags(["-Ounchecked"], .when(configuration: .release))
            ]
        ),
        .executableTarget(
            name: "bench",
            dependencies: ["BinarySearchLab"],
            swiftSettings: [
                .unsafeFlags(["-Ounchecked"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "BinarySearchLabTests",
            dependencies: ["BinarySearchLab"]
        ),
    ]
)
