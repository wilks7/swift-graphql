// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraphQL",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "GraphQL",
            targets: ["GraphQL"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.6"),
    ],
    targets: [
        .target(
            name: "GraphQL"
        ),
        .testTarget(
            name: "GraphQLTests",
            dependencies: ["GraphQL"]
        ),
    ]
)
