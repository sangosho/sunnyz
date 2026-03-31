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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "SunnyZ",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "SunnyZ",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets"),
                .process("Preview Content/Preview Assets.xcassets"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CoreWLAN")
            ]
        ),
        .testTarget(
            name: "SunnyZTests",
            dependencies: ["SunnyZ"],
            path: "SunnyZTests"
        ),
    ]
)
