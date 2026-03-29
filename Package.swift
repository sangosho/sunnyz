// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SunnyZ",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SunnyZ",
            targets: ["SunnyZ"]
        ),
    ],
    dependencies: [
        // No external dependencies for this hackathon project
    ],
    targets: [
        .executableTarget(
            name: "SunnyZ",
            dependencies: [],
            path: "SunnyZ",
            swiftSettings: [
                .unsafeFlags(["-framework", "IOKit"])
            ]
        ),
        .testTarget(
            name: "SunnyZTests",
            dependencies: ["SunnyZ"],
            path: "SunnyZTests"
        ),
    ]
)
