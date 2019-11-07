// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "jsonapi-openapi-test-server",
    platforms: [
        .macOS(.v10_14)
    ],
    products: [
        .library(name: "jsonapi-openapi-test-server", targets: ["App"]),
        .library(name: "jsonapi-openapi-test-lib", targets: ["APITesting"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0-alpha.3"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0-alpha.3"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0-alpha.2.1"),

        .package(url: "https://github.com/ianpartridge/swift-backtrace.git", from: "1.1.1"),

        .package(url: "https://github.com/mattpolzin/JSONAPI-OpenAPI.git", .branch("feature/gen-swift")),
        .package(url: "https://github.com/mattpolzin/OpenAPI.git", from: "0.8.0"),
        .package(url: "https://github.com/mattpolzin/JSONAPI.git", from: "3.0.0-alpha.2")
    ],
    targets: [
        /// MARK: Server App library
        .target(name: "App", dependencies: [
          "Vapor", "Fluent", "FluentPostgresDriver",

          "Backtrace",

          "SwiftGen", "APITesting", "JSONAPI"
        ]),
        .testTarget(name: "AppTests", dependencies: ["App"]),

        /// MARK: Terminal App library
        .target(name: "APITesting", dependencies: [
            "Vapor",

            "SwiftGen"
        ]),

        /// MARK: Server API Documentation library
        .target(name: "AppAPIDocumentation", dependencies: ["App", "JSONAPIOpenAPI"]),

        /// MARK: Executables
        .target(name: "Run", dependencies: ["App"]),
        .target(name: "APITest", dependencies: ["APITesting", "Vapor"]),
        .target(name: "GenAPIDocumentation", dependencies: ["AppAPIDocumentation"]),

        /// MARK: Swift Generation interface
        .target(name: "SwiftGen", dependencies: ["JSONAPIOpenAPI", "OpenAPIKit", "JSONAPISwiftGen"])
    ]
)
