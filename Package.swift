// swift-tools-version:5.2
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
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0-beta.3.24"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0-beta.3"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0-beta.2.4"),

        .package(url: "https://github.com/mattpolzin/VaporTypedRoutes.git", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/mattpolzin/VaporOpenAPI.git", .branch("master")),

        .package(url: "https://github.com/weichsel/ZIPFoundation/", .upToNextMinor(from: "0.9.10")),
        .package(url: "https://github.com/ianpartridge/swift-backtrace.git", from: "1.1.1"),

        .package(url: "https://github.com/mattpolzin/JSONAPI-OpenAPI.git", .branch("feature/gen-swift")),
        .package(url: "https://github.com/mattpolzin/OpenAPIKit.git", .upToNextMinor(from: "0.20.0")),
        .package(url: "https://github.com/mattpolzin/JSONAPI.git", .upToNextMajor(from: "3.0.0"))
    ],
    targets: [
        /// MARK: Server App library
        .target(name: "App", dependencies: [
          .product(name: "Vapor", package: "vapor"), 
          .product(name: "Fluent", package: "fluent"), 
          .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"), 
          "VaporTypedRoutes", 
          "VaporOpenAPI",

          .product(name: "Backtrace", package: "swift-backtrace"),

          "SwiftGen", 
          "APITesting", 
          "JSONAPI"
        ]),
        .testTarget(name: "AppTests", dependencies: ["App"]),

        /// MARK: Terminal App library
        .target(name: "APITesting", dependencies: [
            .product(name: "Vapor", package: "vapor"),

            "SwiftGen"
        ]),

        /// MARK: Server API Documentation library
        .target(name: "AppAPIDocumentation", dependencies: ["App", .product(name: "JSONAPIOpenAPI", package: "JSONAPI-OpenAPI"), "VaporOpenAPI"]),

        /// MARK: Executables
        .target(name: "Run", dependencies: ["App"]),
        .target(name: "APITest", dependencies: ["APITesting", .product(name: "Vapor", package: "vapor")]),
        .target(name: "GenAPIDocumentation", dependencies: ["AppAPIDocumentation"]),

        /// MARK: Swift Generation interface
        .target(name: "SwiftGen", dependencies: [.product(name: "JSONAPIOpenAPI", package: "JSONAPI-OpenAPI"), "OpenAPIKit", .product(name: "JSONAPISwiftGen", package: "JSONAPI-OpenAPI"), "ZIPFoundation"])
    ]
)
