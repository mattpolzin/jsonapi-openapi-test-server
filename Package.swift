// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "jsonapi-openapi-test-server",
    products: [
        .library(name: "jsonapi-openapi-test-server", targets: ["App"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0-alpha.3"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0-alpha.3"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0-alpha.2.1"),
        .package(url: "https://github.com/mattpolzin/JSONAPI-OpenAPI.git", .branch("feature/gen-swift")),
        .package(url: "https://github.com/mattpolzin/OpenAPI.git", .upToNextMinor(from: "0.4.1"))
    ],
    targets: [
        .target(name: "App", dependencies: ["Vapor", "SwiftGen", "Fluent", "FluentPostgresDriver"]),
        .testTarget(name: "AppTests", dependencies: ["App"]),

        .target(name: "Run", dependencies: ["App"]),

        .target(name: "SwiftGen", dependencies: ["JSONAPIOpenAPI", "OpenAPIKit", "JSONAPISwiftGen"])
    ]
)
