// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "jsonapi-openapi-test-server",
    products: [
        .library(name: "jsonapi-openapi-test-server", targets: ["App"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0-alpha.3"),
    ],
    targets: [
        .target(name: "App", dependencies: ["Vapor"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

