// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SunnyZ",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SunnyZ",
            targets: ["SunnyZ"]
        ),
    ],
    dependencies: [
        // No external dependencies for this hackathon project
    ],
    targets: [
        .target(
            name: "SunnyZ",
            dependencies: [],
            path: "SunnyZ"
        ),
        .testTarget(
            name: "SunnyZTests",
            dependencies: ["SunnyZ"],
            path: "SunnyZTests"
        ),
    ]
)
