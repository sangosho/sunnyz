// swift-tools-version:6.0

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
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets"),
                .process("Preview Content/Preview Assets.xcassets"),
            ],
            swiftSettings: [
                .unsafeFlags(["-framework", "IOKit"]),
                .unsafeFlags(["-framework", "ServiceManagement"])
            ]
        ),
        .testTarget(
            name: "SunnyZTests",
            dependencies: ["SunnyZ"],
            path: "SunnyZTests"
        ),
    ]
)
