import XCTest
import Fluent
import XCTVapor
import XCTFluent

import App
import APITesting
import APIModels

import JSONAPITesting

final class APITestPropertiesControllerTests: XCTestCase {

    func test_createEndpoint_emptyRequestBody_fails() throws {
        let app = try testApp()
        defer { app.shutdown() }

        try configureDefaults(for: app)
        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        let propertiesController = APITestPropertiesController(
            openAPISource: nil
        )

        propertiesController.mount(on: app, at: "api_test_properties")

        try app.testable().test(.POST, "api_test_properties") { res in
            XCTAssertEqual(res.status, HTTPStatus.unprocessableEntity)
        }
    }

    func test_createEndpoint_withoutSourceOrDefault_fails() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        let propertiesController = APITestPropertiesController(
            openAPISource: nil
        )

        propertiesController.mount(on: app, at: "api_test_properties")

        let requestedNewProperties = API.NewAPITestProperties(
            attributes: .init(apiHostOverride: nil, parser: .stable),
            relationships: .init(openAPISource: nil),
            meta: .none,
            links: .none
        )

        let requestBody = API.CreateAPITestPropertiesDocument(
            apiDescription: .none,
            body: .init(resourceObject: requestedNewProperties),
            includes: .none,
            meta: .none,
            links: .none
        )

        try app.testable().test(.POST, "api_test_properties", beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { res in
            XCTAssertEqual(res.status, HTTPStatus.badRequest)
        }
    }

    func test_createEndpoint_withoutSourceButWithDefault_succeeds() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        // expect the database to be queried to retrieve the default source
        // and serve up empty result
        testDatabase.append([])
        // expect the database to be queried to create the default source
        // and serve up the created resource
        testDatabase.append([
            TestOutput(DB.OpenAPISource(uri: "/hello/world.json", sourceType: .filepath))
        ])
        // expect the database to be queried to create a new API Test Properties resource
        // and serve up the craeted resource
        testDatabase.append([
            TestOutput(DB.APITestProperties(openAPISourceId: UUID(), apiHostOverride: nil, parser: .stable))
        ])

        let defaultSource = OpenAPISource.file(path: "/hello/world.json")

        let propertiesController = APITestPropertiesController(
            openAPISource: defaultSource
        )

        propertiesController.mount(on: app, at: "api_test_properties")

        // create the POST request body
        let requestedNewProperties = API.NewAPITestProperties(
            attributes: .init(apiHostOverride: nil, parser: .stable),
            relationships: .init(openAPISource: nil),
            meta: .none,
            links: .none
        )

        let requestBody = API.CreateAPITestPropertiesDocument(
            apiDescription: .none,
            body: .init(resourceObject: requestedNewProperties),
            includes: .none,
            meta: .none,
            links: .none
        )

        // make the test request
        try app.testable().test(.POST, "api_test_properties", beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { res in
            XCTAssertEqual(res.status, HTTPStatus.created)
        }
    }

    func test_indexEndpoint_emptyResult_succeeds() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        testDatabase.append([])

        app.databases.use(testDatabase.configuration, as: .psql)

        let propertiesController = APITestPropertiesController(
            openAPISource: nil
        )

        propertiesController.mount(on: app, at: "api_test_properties")

        try app.testable().test(.GET, "api_test_properties") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok)

            let body = try res.content.decode(API.BatchAPITestPropertiesDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            XCTAssertEqual(body.data.primary.values, [])
            XCTAssertEqual(body.data.includes.values, [])
        }
    }

    func test_indexEndpoint_populatedResult_succeeds() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        let openAPISourceUUIDs = [
            UUID(),
            UUID()
        ]

        let testProperties = [
            DB.APITestProperties(openAPISourceId: openAPISourceUUIDs[0], apiHostOverride: nil, parser: .stable),
            DB.APITestProperties(openAPISourceId: openAPISourceUUIDs[1], apiHostOverride: URL(string: "http://website.com")!, parser: .fast)
        ]

        testDatabase.append([
            TestOutput(testProperties[0]),
            TestOutput(testProperties[1])
        ])

        app.databases.use(testDatabase.configuration, as: .psql)

        let propertiesController = APITestPropertiesController(
            openAPISource: nil
        )

        propertiesController.mount(on: app, at: "api_test_properties")

        let expectedValues = [
            API.APITestProperties(
                id: .init(rawValue: testProperties[0].id!),
                attributes: .init(createdAt: testProperties[0].createdAt, apiHostOverride: testProperties[0].apiHostOverride, parser: .stable),
                relationships: .init(openAPISource: .init(id: .init(rawValue: openAPISourceUUIDs[0]))),
                meta: .none,
                links: .none
            ),
            API.APITestProperties(
                id: .init(rawValue: testProperties[1].id!),
                attributes: .init(createdAt: testProperties[1].createdAt, apiHostOverride: testProperties[1].apiHostOverride, parser: .fast),
                relationships: .init(openAPISource: .init(id: .init(rawValue: openAPISourceUUIDs[1]))),
                meta: .none,
                links: .none
            )
        ]

        try app.testable().test(.GET, "api_test_properties") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok)

            let body = try res.content.decode(API.BatchAPITestPropertiesDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparisons = zip(bodyData.primary.values, expectedValues).map { $0.0.compare(to: $0.1) }
            for comparison in comparisons {
                XCTAssert(comparison.isSame, String(describing: comparison))
            }
            XCTAssertEqual(body.data.includes.values, [])
        }
    }

    func test_indexEndpoint_populatedResultWithIncludes_succeeds() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        let openAPISourceUUIDs = [
            UUID(),
            UUID()
        ]

        let testProperties = [
            DB.APITestProperties(openAPISourceId: openAPISourceUUIDs[0], apiHostOverride: nil, parser: .stable),
            DB.APITestProperties(openAPISourceId: openAPISourceUUIDs[1], apiHostOverride: URL(string: "http://website.com")!, parser: .fast)
        ]

        let testSources = [
            DB.OpenAPISource(id: openAPISourceUUIDs[0], uri: "http://website.com/source.yml", sourceType: .url),
            DB.OpenAPISource(id: openAPISourceUUIDs[1], uri: "http://the.website.com/other.yml", sourceType: .url)
        ]

        testDatabase.append([
            TestOutput(testProperties[0]),
            TestOutput(testProperties[1])
        ])

        testDatabase.append([
            TestOutput(testSources[0]),
            TestOutput(testSources[1])
        ])

        let propertiesController = APITestPropertiesController(
            openAPISource: nil
        )

        propertiesController.mount(on: app, at: "api_test_properties")

        let expectedPrimaries = [
            API.APITestProperties(
                id: .init(rawValue: testProperties[0].id!),
                attributes: .init(createdAt: testProperties[0].createdAt, apiHostOverride: testProperties[0].apiHostOverride, parser: .stable),
                relationships: .init(openAPISource: .init(id: .init(rawValue: openAPISourceUUIDs[0]))),
                meta: .none,
                links: .none
            ),
            API.APITestProperties(
                id: .init(rawValue: testProperties[1].id!),
                attributes: .init(createdAt: testProperties[1].createdAt, apiHostOverride: testProperties[1].apiHostOverride, parser: .fast),
                relationships: .init(openAPISource: .init(id: .init(rawValue: openAPISourceUUIDs[1]))),
                meta: .none,
                links: .none
            )
        ]

        let expectedIncludes = [
            API.OpenAPISource(
                id: .init(rawValue: openAPISourceUUIDs[0]),
                attributes: .init(
                    createdAt: testSources[0].createdAt,
                    uri: testSources[0].uri,
                    sourceType: testSources[0].sourceType
                ),
                relationships: .none,
                meta: .none,
                links: .none
            ),
            API.OpenAPISource(
                id: .init(rawValue: openAPISourceUUIDs[1]),
                attributes: .init(
                    createdAt: testSources[1].createdAt,
                    uri: testSources[1].uri,
                    sourceType: testSources[1].sourceType
                ),
                relationships: .none,
                meta: .none,
                links: .none
            )
        ]

        try app.testable().test(.GET, "api_test_properties?include=openAPISource") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok, "with body:\n\(res.body.string)")

            let body = try res.content.decode(API.BatchAPITestPropertiesDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparison1 = bodyData.primary.values[0].compare(to: expectedPrimaries[0])
            XCTAssert(comparison1.isSame, String(describing: comparison1))
            let comparison2 = bodyData.primary.values[1].compare(to: expectedPrimaries[1])
            XCTAssert(comparison2.isSame, String(describing: comparison2))
            let includeComparison1 = bodyData.includes.values[0].a?.compare(to: expectedIncludes[0])
            XCTAssert(includeComparison1?.isSame ?? false, String(describing: includeComparison1))
            let includeComparison2 = bodyData.includes.values[1].a?.compare(to: expectedIncludes[1])
            XCTAssert(includeComparison2?.isSame ?? false, String(describing: includeComparison2))
        }
    }

    func test_showEndpoint_malformedId_fails() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let propertiesController = APITestPropertiesController(
            openAPISource: nil
        )

        propertiesController.mount(on: app, at: "api_test_properties")

        try app.testable().test(.GET, "api_test_properties/1234") { res in
            XCTAssertEqual(res.status, HTTPStatus.badRequest)
        }
    }

    func test_showEndpoint_missingResult_fails() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        // expect a database query to find the properties resource
        // and respond with an empty result
        testDatabase.append([])

        let propertiesController = APITestPropertiesController(
            openAPISource: nil
        )

        propertiesController.mount(on: app, at: "api_test_properties")

        try app.testable().test(.GET, "api_test_properties/B40806D3-B71E-4626-9878-0DE98EFC6CEC") { res in
            XCTAssertEqual(res.status, HTTPStatus.notFound)
        }
    }

    func test_showEndpoint_foundResult_succeeds() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        let sourceUUID = UUID()
        let testProperty = DB.APITestProperties(openAPISourceId: sourceUUID, apiHostOverride: nil, parser: .stable)

        // expect a database query to find the properties resource
        // and respond with a resource
        testDatabase.append([
            TestOutput(testProperty)
        ])

        let propertiesController = APITestPropertiesController(
            openAPISource: nil
        )

        propertiesController.mount(on: app, at: "api_test_properties")

        let expectedValue = API.APITestProperties(
            id: .init(rawValue: testProperty.id!),
            attributes: .init(createdAt: testProperty.createdAt, apiHostOverride: testProperty.apiHostOverride, parser: .stable),
            relationships: .init(openAPISource: .init(id: .init(rawValue: sourceUUID))),
            meta: .none,
            links: .none
        )

        try app.testable().test(.GET, "api_test_properties/\(testProperty.id!.uuidString)") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok)

            let body = try res.content.decode(API.SingleAPITestPropertiesDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparison = bodyData.primary.value.compare(to: expectedValue)
            XCTAssert(comparison.isSame, String(describing: comparison))
            XCTAssertEqual(body.data.includes.values, [])
        }
    }

    func test_showEndpoint_foundResultWithIncludes_succeeds() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        let sourceUUID = UUID()
        let testProperty = DB.APITestProperties(openAPISourceId: sourceUUID, apiHostOverride: nil, parser: .stable)
        let testSource = DB.OpenAPISource(id: sourceUUID, uri: "http://website.com/source.yml", sourceType: .url)

        // expect a database query to find the properties resource
        // and respond with a resource
        testDatabase.append([
            TestOutput(testProperty)
        ])
        // expect a database query to find the related openapi source.
        testDatabase.append([
            TestOutput(testSource)
        ])

        let propertiesController = APITestPropertiesController(
            openAPISource: nil
        )

        propertiesController.mount(on: app, at: "api_test_properties")

        let expectedPrimary = API.APITestProperties(
            id: .init(rawValue: testProperty.id!),
            attributes: .init(createdAt: testProperty.createdAt, apiHostOverride: testProperty.apiHostOverride, parser: .stable),
            relationships: .init(openAPISource: .init(id: .init(rawValue: sourceUUID))),
            meta: .none,
            links: .none
        )

        let expectedInclude = API.OpenAPISource(
            id: .init(rawValue: sourceUUID),
            attributes: .init(
                createdAt: testSource.createdAt,
                uri: testSource.uri,
                sourceType: testSource.sourceType
            ),
            relationships: .none,
            meta: .none,
            links: .none
        )

        try app.testable().test(.GET, "api_test_properties/\(testProperty.id!.uuidString)?include=openAPISource") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok, "with body:\n\(res.body.string)")

            let body = try res.content.decode(API.SingleAPITestPropertiesDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparison = bodyData.primary.value.compare(to: expectedPrimary)
            XCTAssert(comparison.isSame, String(describing: comparison))
            let includeComparison = bodyData.includes.values[0].a?.compare(to: expectedInclude)
            XCTAssert(includeComparison?.isSame ?? false, String(describing: includeComparison))
        }
    }
}
