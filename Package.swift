// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "There",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "There", targets: ["There"]),
    ],
    targets: [
        .target(name: "ThereCore"),
        .executableTarget(name: "There", dependencies: ["ThereCore"]),
        .testTarget(name: "ThereTests", dependencies: ["ThereCore"]),
    ]
)
