// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexLimitPeek",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexLimitPeek", targets: ["CodexLimitPeek"])
    ],
    targets: [
        .executableTarget(
            name: "CodexLimitPeek"
        ),
        .testTarget(
            name: "CodexLimitPeekTests",
            dependencies: ["CodexLimitPeek"]
        )
    ]
)
