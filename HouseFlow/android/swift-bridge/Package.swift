// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HouseFlowAndroidBridge",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HouseFlowAndroidBridge", type: .dynamic, targets: ["HouseFlowAndroidBridge"]),
    ],
    dependencies: [
        .package(path: "../../shared"),
        .package(url: "https://github.com/swiftlang/swift-java", exact: "0.6.0"),
    ],
    targets: [
        .target(
            name: "HouseFlowAndroidBridge",
            dependencies: [
                .product(name: "HouseFlowCore", package: "shared"),
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            plugins: [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")]
        ),
        .testTarget(name: "HouseFlowAndroidBridgeTests", dependencies: ["HouseFlowAndroidBridge"]),
    ]
)
