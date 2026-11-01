// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FausCrewShared",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "FausCrewCore",
            targets: ["FausCrewCore"]
        ),
    ],
    targets: [
        .target(
            name: "FausCrewCore"
        ),
        .testTarget(
            name: "FausCrewCoreTests",
            dependencies: ["FausCrewCore"]
        ),
    ]
)
