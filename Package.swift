// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "jsonapi-openapi-test-server",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "jsonapi-openapi-test-server", targets: ["App"]),
        .library(name: "jsonapi-openapi-test-lib", targets: ["APITesting"]),
        .library(name: "TestServerModels", targets: ["APIModels"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0-rc.1"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0-rc.2"),

        .package(url: "https://github.com/mattpolzin/VaporTypedRoutes.git", .upToNextMinor(from: "0.3.0")),
        .package(url: "https://github.com/mattpolzin/VaporOpenAPI.git", .upToNextMinor(from: "0.0.5")),

        .package(url: "https://github.com/weichsel/ZIPFoundation/", .upToNextMinor(from: "0.9.10")),

        .package(name: "JSONAPI-OpenAPI", url: "https://github.com/mattpolzin/JSONAPI-OpenAPI.git", .branch("feature/gen-swift")),
        .package(url: "https://github.com/mattpolzin/OpenAPIKit.git", .upToNextMinor(from: "0.28.0")),
        .package(url: "https://github.com/mattpolzin/JSONAPI.git", .upToNextMajor(from: "3.0.0")),
        .package(url: "https://github.com/jpsim/Yams.git", .upToNextMajor(from: "2.0.0"))
    ],
    targets: [
        /// MARK: Server App library
        .target(name: "APIModels", dependencies: [
            "JSONAPI"
        ]),
        .target(name: "App", dependencies: [
          .product(name: "Vapor", package: "vapor"), 
          .product(name: "Fluent", package: "fluent"), 
          .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"), 
          "VaporTypedRoutes", 
          "VaporOpenAPI",

          "SwiftGen", 
          "APITesting", 
          "JSONAPI",
          "APIModels"
        ]),
        .testTarget(name: "AppTests", dependencies: ["App", .product(name: "Fluent", package: "fluent"), .product(name: "Vapor", package: "vapor")]),

        /// MARK: Terminal App library
        .target(name: "APITesting", dependencies: [
            .product(name: "Vapor", package: "vapor"),

            "SwiftGen",
            "Yams"
        ]),

        /// MARK: Server API Documentation library
        .target(name: "AppAPIDocumentation", dependencies: [
            "App",
            .product(name: "JSONAPIOpenAPI", package: "JSONAPI-OpenAPI"),
            "VaporOpenAPI"
        ]),

        /// MARK: Executables
        .target(name: "Run", dependencies: ["App"]),
        .target(name: "APITest", dependencies: [
            "APITesting",
            .product(name: "Vapor", package: "vapor")
        ]),
        .target(name: "GenAPIDocumentation", dependencies: ["AppAPIDocumentation"]),

        /// MARK: Swift Generation interface
        .target(name: "SwiftGen", dependencies: [
            .product(name: "JSONAPIOpenAPI", package: "JSONAPI-OpenAPI"),
            "OpenAPIKit",
            .product(name: "JSONAPISwiftGen", package: "JSONAPI-OpenAPI"),
            "ZIPFoundation"
        ])
    ]
)
