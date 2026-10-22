// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FausCrewAndroidBridge",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FausCrewAndroidBridge", type: .dynamic, targets: ["FausCrewAndroidBridge"]),
    ],
    dependencies: [
        .package(path: "../../shared"),
        .package(url: "https://github.com/swiftlang/swift-java", exact: "0.6.0"),
    ],
    targets: [
        .target(
            name: "FausCrewAndroidBridge",
            dependencies: [
                .product(name: "FausCrewCore", package: "shared"),
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            plugins: [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")]
        ),
        .testTarget(name: "FausCrewAndroidBridgeTests", dependencies: ["FausCrewAndroidBridge"]),
    ]
)
