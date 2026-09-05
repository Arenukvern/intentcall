// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "intentcall_platform_apple",
    platforms: [
        .iOS("13.0"),
        .macOS("10.14"),
    ],
    products: [
        .library(name: "intentcall-platform-apple", targets: ["intentcall_platform_apple"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "intentcall_platform_apple",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
