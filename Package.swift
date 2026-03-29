// swift-tools-version:5.7

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
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SunnyZ",
            dependencies: [],
            path: "SunnyZ",
            swiftSettings: [
                .unsafeFlags(["-framework", "IOKit"]),
                .unsafeFlags(["-framework", "ServiceManagement"])
            ]
        ),
    ]
)
