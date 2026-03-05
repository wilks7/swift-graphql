// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-graphql",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "GraphQL",
            targets: ["GraphQL"]),
    ],
    dependencies: [],
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
