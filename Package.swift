// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "jsonapi-openapi-test-server",
    platforms: [
        .macOS(.v12),
        .iOS(.v10)
    ],
    products: [
        .library(name: "jsonapi-openapi-test-server", targets: ["App"]),
        .library(name: "jsonapi-openapi-test-lib", targets: ["APITesting"]),
        .library(name: "TestServerModels", targets: ["APIModels"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.5.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.1.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-kit.git", from: "1.7.0"),
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0-rc.3"),

        .package(url: "https://github.com/mattpolzin/VaporTypedRoutes.git", .upToNextMinor(from: "0.9.0")),
        .package(url: "https://github.com/mattpolzin/VaporOpenAPI.git", .branch("openapikit-3")),

        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMinor(from: "0.9.10")),

        .package(name: "JSONAPI-OpenAPI", url: "https://github.com/mattpolzin/JSONAPI-OpenAPI.git", .branch("openapikit-3")),
        .package(url: "https://github.com/mattpolzin/OpenAPIKit.git", .branch("release/3_0")),
        .package(url: "https://github.com/mattpolzin/JSONAPI.git", from: "5.1.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/fabianfett/pure-swift-json.git", .upToNextMinor(from: "0.4.0")),

        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0")
    ],
    targets: [
        // MARK: API Models
        .target(name: "APIModels", dependencies: [
            "JSONAPI"
        ]),

        // MARK: Server App Library
        .target(name: "App", dependencies: [
          .product(name: "Vapor", package: "vapor"), 
          .product(name: "Fluent", package: "fluent"),
          .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"), 
          .product(name: "QueuesRedisDriver", package: "queues-redis-driver"),
          .product(name: "VaporTypedRoutes", package: "VaporTypedRoutes"),
          .product(name: "VaporOpenAPI", package: "VaporOpenAPI"),

          .product(name: "JSONAPI", package: "JSONAPI"),

          "SwiftGen",
          "APITesting",
          "APIModels"
        ]),
        .testTarget(name: "AppTests", dependencies: [
            "App",
            .product(name: "Fluent", package: "fluent"),
            .product(name: "Vapor", package: "vapor"),
            .product(name: "XCTVapor", package: "vapor"),
            .product(name: "XCTFluent", package: "fluent-kit"),
            .product(name: "JSONAPITesting", package: "JSONAPI")
        ]),

        // MARK: Terminal App library
        .target(name: "APITesting", dependencies: [
            .product(name: "Vapor", package: "vapor"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),

            .product(name: "Yams", package: "Yams"),
            .product(name: "PureSwiftJSON", package: "pure-swift-json"),

            "SwiftGen"
        ]),

        // MARK: Server API Documentation library
        .target(name: "AppAPIDocumentation", dependencies: [
            "App",
            .product(name: "JSONAPIOpenAPI", package: "JSONAPI-OpenAPI"),
            .product(name: "VaporOpenAPI", package: "VaporOpenAPI")
        ]),

        // MARK: Executables
        .executableTarget(name: "Run", dependencies: ["App"]),
        .executableTarget(name: "APITest", dependencies: [
            "APITesting",
            .product(name: "Vapor", package: "vapor")
        ]),
        .executableTarget(name: "GenAPIDocumentation", dependencies: [
            "AppAPIDocumentation"
        ]),

        // MARK: Swift Generation interface
        .target(name: "SwiftGen", dependencies: [
            .product(name: "JSONAPIOpenAPI", package: "JSONAPI-OpenAPI"),
            .product(name: "OpenAPIKit30", package: "OpenAPIKit"),
            .product(name: "JSONAPISwiftGen", package: "JSONAPI-OpenAPI"),
            .product(name: "ZIPFoundation", package: "ZIPFoundation")
        ])
    ]
)
