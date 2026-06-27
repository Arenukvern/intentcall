// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "intentcall_platform",
    platforms: [
        .macOS("10.14")
    ],
    products: [
        .library(name: "intentcall-platform", targets: ["intentcall_platform"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "intentcall_platform",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // The plugin does not currently collect data. Keep the
                // manifest ready for future changes.
                // .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
