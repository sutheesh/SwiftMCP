// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftMCP",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "SwiftMCP",
            targets: ["SwiftMCP"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/modelcontextprotocol/swift-sdk",
            from: "0.9.0"
        ),
    ],
    targets: [
        .target(
            name: "SwiftMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/SwiftMCP",
        ),
        .testTarget(
            name: "SwiftMCPTests",
            dependencies: ["SwiftMCP"],
            path: "Tests/SwiftMCPTests"
        ),
    ]
)
