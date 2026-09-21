// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DraftBook",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DraftBookCore", targets: ["DraftBookCore"]),
        .executable(name: "DraftBook", targets: ["DraftBook"])
    ],
    targets: [
        .target(name: "DraftBookCore"),
        .executableTarget(
            name: "DraftBook",
            dependencies: ["DraftBookCore"]
        ),
        .testTarget(
            name: "DraftBookCoreTests",
            dependencies: ["DraftBookCore"]
        )
    ]
)
