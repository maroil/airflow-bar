// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AirflowBar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AirflowBarCore", targets: ["AirflowBarCore"]),
        .executable(name: "AirflowBar", targets: ["AirflowBar"]),
    ],
    targets: [
        .target(
            name: "AirflowBarCore",
            path: "Sources/AirflowBarCore"
        ),
        .executableTarget(
            name: "AirflowBar",
            dependencies: ["AirflowBarCore"],
            path: "Sources/AirflowBar",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "AirflowBarCoreTests",
            dependencies: ["AirflowBarCore"],
            path: "Tests/AirflowBarCoreTests"
        ),
    ]
)
