// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "TokenUsageCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TokenUsageCore",
            targets: ["TokenUsageCore"]
        ),
    ],
    targets: [
        .target(
            name: "TokenUsageCore"
        ),
        .testTarget(
            name: "TokenUsageCoreTests",
            dependencies: ["TokenUsageCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
