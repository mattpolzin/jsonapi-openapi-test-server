// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "jsonapi-openapi-test-server",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v10)
    ],
    products: [
        .library(name: "jsonapi-openapi-test-server", targets: ["App"]),
        .library(name: "jsonapi-openapi-test-lib", targets: ["APITesting"]),
        .library(name: "TestServerModels", targets: ["APIModels"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", .upToNextMajor(from: "4.5.0")),
        .package(url: "https://github.com/vapor/fluent-postgres-driver", from: "2.0.0-rc.2"),
        .package(url: "https://github.com/vapor/fluent", from: "4.0.0-rc.2.2"),
        .package(url: "https://github.com/vapor/fluent-kit", from: "1.0.0-rc.1.26"),
        .package(url: "https://github.com/vapor/queues-redis-driver", .branch("master")),

        .package(url: "https://github.com/mattpolzin/VaporTypedRoutes", .upToNextMinor(from: "0.7.0")),
        .package(url: "https://github.com/mattpolzin/VaporOpenAPI", .upToNextMinor(from: "0.0.13")),

        .package(url: "https://github.com/weichsel/ZIPFoundation/", .upToNextMinor(from: "0.9.10")),

        .package(name: "JSONAPI-OpenAPI", url: "https://github.com/mattpolzin/JSONAPI-OpenAPI", .upToNextMinor(from: "0.23.0")),
        // .package(name: "JSONAPI-OpenAPI", path: "../JSONAPI-OpenAPI"),
        .package(url: "https://github.com/mattpolzin/OpenAPIKit", from: "1.4.0"),
        .package(url: "https://github.com/mattpolzin/JSONAPI", from: "4.0.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "3.0.0"),
        .package(url: "https://github.com/fabianfett/pure-swift-json", .upToNextMinor(from: "0.4.0")),

        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.0.6"))
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
        .target(name: "Run", dependencies: ["App"]),
        .target(name: "APITest", dependencies: [
            "APITesting",
            .product(name: "Vapor", package: "vapor")
        ]),
        .target(name: "GenAPIDocumentation", dependencies: [
            "AppAPIDocumentation"
        ]),

        // MARK: Swift Generation interface
        .target(name: "SwiftGen", dependencies: [
            .product(name: "JSONAPIOpenAPI", package: "JSONAPI-OpenAPI"),
            .product(name: "OpenAPIKit", package: "OpenAPIKit"),
            .product(name: "JSONAPISwiftGen", package: "JSONAPI-OpenAPI"),
            .product(name: "ZIPFoundation", package: "ZIPFoundation")
        ])
    ]
)
