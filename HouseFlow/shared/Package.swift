// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HouseFlowShared",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "HouseFlowCore",
            targets: ["HouseFlowCore"]
        ),
    ],
    targets: [
        .target(
            name: "HouseFlowCore"
        ),
        .testTarget(
            name: "HouseFlowCoreTests",
            dependencies: ["HouseFlowCore"]
        ),
    ]
)
