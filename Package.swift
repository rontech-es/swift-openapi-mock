// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-openapi-mock",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "OpenAPIMock",
            targets: ["OpenAPIMock"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-openapi-runtime",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "OpenAPIMock",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ]
        ),
        .testTarget(
            name: "OpenAPIMockTests",
            dependencies: ["OpenAPIMock"]
        ),
    ]
)
