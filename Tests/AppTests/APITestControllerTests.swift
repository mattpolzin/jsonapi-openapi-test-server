import XCTest
import Fluent
import XCTVapor
import XCTFluent

import App
import APITesting
import APIModels

import JSONAPITesting

final class APITestControllerTests: XCTestCase {

    func test_createEndpoint_emptyRequestBody_fails() throws {
        let app = try testApp()
        defer { app.shutdown() }

        try configureDefaults(for: app)
        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        let testController = APITestController(
            outputPath: FileManager.default.temporaryDirectory.absoluteString,
            openAPISource: nil
        )

        testController.mount(on: app, at: "api_tests")

        try app.testable().test(.POST, "api_tests") { res in
            XCTAssertEqual(res.status, HTTPStatus.unprocessableEntity)
        }
    }

    func test_createEndpoint_withoutSourceOrDefault_fails() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        let testController = APITestController(
            outputPath: FileManager.default.temporaryDirectory.absoluteString,
            openAPISource: nil
        )

        testController.mount(on: app, at: "api_tests")

        let requestedNewTest = API.NewAPITestDescriptor(
            attributes: .none,
            relationships: .init(testProperties: nil),
            meta: .none,
            links: .none
        )

        let requestBody = API.CreateAPITestDescriptorDocument(
            apiDescription: .none,
            body: .init(resourceObject: requestedNewTest),
            includes: .none,
            meta: .none,
            links: .none
        )

        try app.testable().test(.POST, "api_tests", beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { res in
            XCTAssertEqual(res.status, HTTPStatus.badRequest)
        }
    }

//    func test_createEndpoint_withoutSourceButWithDefault_succeeds() throws {
//        let app = try testApp()
//        defer { app.shutdown() }
//
//        app.middleware.use(JSONAPIErrorMiddleware())
//
//        let testDatabase = ArrayTestDatabase()
//
//        app.databases.use(testDatabase.configuration, as: .psql)
//
//        // expect the database to be queried to retrieve the default source
//        // and serve up empty result
//        testDatabase.append([])
//        // expect the database to be queried to create the default source
//        // and serve up the created resource
//        testDatabase.append([
//            TestOutput(DB.OpenAPISource(uri: "/hello/world.json", sourceType: .filepath))
//        ])
//        // expect the database to be queried to create a new API Test Properties resource
//        // and serve up the craeted resource
//        testDatabase.append([
//            TestOutput(DB.APITestProperties(openAPISourceId: UUID(), apiHostOverride: nil))
//        ])
//
//        let defaultSource = OpenAPISource.file(path: "/hello/world.json")
//
//        let propertiesController = APITestPropertiesController(
//            openAPISource: defaultSource
//        )
//
//        propertiesController.mount(on: app, at: "api_tests")
//
//        // create the POST request body
//        let requestedNewProperties = API.NewAPITestProperties(
//            attributes: .init(apiHostOverride: nil),
//            relationships: .init(openAPISource: nil),
//            meta: .none,
//            links: .none
//        )
//
//        let requestBody = API.CreateAPITestPropertiesDocument(
//            apiDescription: .none,
//            body: .init(resourceObject: requestedNewProperties),
//            includes: .none,
//            meta: .none,
//            links: .none
//        )
//
//        // make the test request
//        try app.testable().test(.POST, "api_tests", beforeRequest: { req in
//            try req.content.encode(requestBody)
//        }) { res in
//            XCTAssertEqual(res.status, HTTPStatus.created)
//        }
//    }

    func test_indexEndpoint_emptyResult_succeeds() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        // expect request for test descriptors and return an empty
        // result.
        testDatabase.append([])

        app.databases.use(testDatabase.configuration, as: .psql)

        let testController = APITestController(
            outputPath: FileManager.default.temporaryDirectory.absoluteString,
            openAPISource: nil
        )

        testController.mount(on: app, at: "api_tests")

        try app.testable().test(.GET, "api_tests") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok)

            let body = try res.content.decode(API.BatchAPITestDescriptorDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

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

        let testDescriptors = [
            try DB.APITestDescriptor(id: UUID(), testProperties: testProperties[0]),
            try DB.APITestDescriptor(id: UUID(), testProperties: testProperties[1])
        ]

        testDatabase.append([
            TestOutput(testDescriptors[0]),
            TestOutput(testDescriptors[1])
        ])
        // expect a query for messages because that is a to-many relationship
        // so we need to query for them even if they are not being included.
        // we can just respond with empty result for no messages.
        testDatabase.append([])

        app.databases.use(testDatabase.configuration, as: .psql)

        let testController = APITestController(
            outputPath: FileManager.default.temporaryDirectory.absoluteString,
            openAPISource: nil
        )

        testController.mount(on: app, at: "api_tests")

        let expectedValues = [
            API.APITestDescriptor(
                id: .init(rawValue: testDescriptors[0].id!),
                attributes: .init(createdAt: testDescriptors[0].createdAt, finishedAt: testDescriptors[0].finishedAt, status: testDescriptors[0].status),
                relationships: .init(testPropertiesId: .init(rawValue: testProperties[0].id!), messageIds: []),
                meta: .none,
                links: .none
            ),
            API.APITestDescriptor(
                id: .init(rawValue: testDescriptors[1].id!),
                attributes: .init(createdAt: testDescriptors[1].createdAt, finishedAt: testDescriptors[1].finishedAt, status: testDescriptors[1].status),
                relationships: .init(testPropertiesId: .init(rawValue: testProperties[1].id!), messageIds: []),
                meta: .none,
                links: .none
            )
        ]

        try app.testable().test(.GET, "api_tests") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok, "with body: \(res.body.string)")

            let body = try res.content.decode(API.BatchAPITestDescriptorDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparisons = zip(bodyData.primary.values, expectedValues).map { $0.0.compare(to: $0.1) }
            for comparison in comparisons {
                XCTAssert(comparison.isSame, String(describing: comparison))
            }
            XCTAssertEqual(body.data.includes.values, [])
        }
    }

    func test_indexEndpoint_populatedResultWithMessagesNotIncluded_succeeds() throws {
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

        let testDescriptors = [
            try DB.APITestDescriptor(id: UUID(), testProperties: testProperties[0]),
            try DB.APITestDescriptor(id: UUID(), testProperties: testProperties[1])
        ]

        let testMessage = try DB.APITestMessage(
            testDescriptor: testDescriptors[0],
            messageType: .info,
            path: nil,
            context: nil,
            message: "hello world"
        )

        testDatabase.append([
            TestOutput(testDescriptors[0]),
            TestOutput(testDescriptors[1])
        ])
        // expect a query for messages because that is a to-many relationship
        // so we need to query for them even if they are not being included.
        testDatabase.append([
            TestOutput(testMessage)
        ])

        app.databases.use(testDatabase.configuration, as: .psql)

        let testController = APITestController(
            outputPath: FileManager.default.temporaryDirectory.absoluteString,
            openAPISource: nil
        )

        testController.mount(on: app, at: "api_tests")

        let expectedValues = [
            API.APITestDescriptor(
                id: .init(rawValue: testDescriptors[0].id!),
                attributes: .init(createdAt: testDescriptors[0].createdAt, finishedAt: testDescriptors[0].finishedAt, status: testDescriptors[0].status),
                relationships: .init(testPropertiesId: .init(rawValue: testProperties[0].id!), messageIds: [.init(rawValue: testMessage.id!)]),
                meta: .none,
                links: .none
            ),
            API.APITestDescriptor(
                id: .init(rawValue: testDescriptors[1].id!),
                attributes: .init(createdAt: testDescriptors[1].createdAt, finishedAt: testDescriptors[1].finishedAt, status: testDescriptors[1].status),
                relationships: .init(testPropertiesId: .init(rawValue: testProperties[1].id!), messageIds: []),
                meta: .none,
                links: .none
            )
        ]

        try app.testable().test(.GET, "api_tests") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok, "with body: \(res.body.string)")

            let body = try res.content.decode(API.BatchAPITestDescriptorDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparisons = zip(bodyData.primary.values, expectedValues).map { $0.0.compare(to: $0.1) }
            for comparison in comparisons {
                XCTAssert(comparison.isSame, String(describing: comparison))
            }
            XCTAssertEqual(body.data.includes.values, [])
        }
    }

    func test_indexEndpoint_populatedResultWithMessageIncludes_succeeds() throws {
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

        let testDescriptors = [
            try DB.APITestDescriptor(id: UUID(), testProperties: testProperties[0]),
            try DB.APITestDescriptor(id: UUID(), testProperties: testProperties[1])
        ]

        let testMessage = try DB.APITestMessage(
            testDescriptor: testDescriptors[0],
            messageType: .info,
            path: nil,
            context: nil,
            message: "hello world"
        )

        testDatabase.append([
            TestOutput(testDescriptors[0]),
            TestOutput(testDescriptors[1])
        ])
        // expect a query for messages because that is a to-many relationship
        // so we need to query for them even if they are not being included.
        testDatabase.append([
            TestOutput(testMessage)
        ])

        app.databases.use(testDatabase.configuration, as: .psql)

        let testController = APITestController(
            outputPath: FileManager.default.temporaryDirectory.absoluteString,
            openAPISource: nil
        )

        testController.mount(on: app, at: "api_tests")

        let expectedValues = [
            API.APITestDescriptor(
                id: .init(rawValue: testDescriptors[0].id!),
                attributes: .init(createdAt: testDescriptors[0].createdAt, finishedAt: testDescriptors[0].finishedAt, status: testDescriptors[0].status),
                relationships: .init(testPropertiesId: .init(rawValue: testProperties[0].id!), messageIds: [.init(rawValue: testMessage.id!)]),
                meta: .none,
                links: .none
            ),
            API.APITestDescriptor(
                id: .init(rawValue: testDescriptors[1].id!),
                attributes: .init(createdAt: testDescriptors[1].createdAt, finishedAt: testDescriptors[1].finishedAt, status: testDescriptors[1].status),
                relationships: .init(testPropertiesId: .init(rawValue: testProperties[1].id!), messageIds: []),
                meta: .none,
                links: .none
            )
        ]

        let expectedIncludes = [
            API.APITestMessage(
                id: .init(rawValue: testMessage.id!),
                attributes: .init(
                    createdAt: testMessage.createdAt,
                    messageType: testMessage.messageType,
                    path: testMessage.path,
                    context: testMessage.context,
                    message: testMessage.message
                ),
                relationships: .init(apiTestDescriptorId: .init(rawValue: testMessage.$apiTestDescriptor.id)),
                meta: .none,
                links: .none
            )
        ]

        try app.testable().test(.GET, "api_tests?include=messages") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok, "with body: \(res.body.string)")

            let body = try res.content.decode(API.BatchAPITestDescriptorDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparisons = zip(bodyData.primary.values, expectedValues).map { $0.0.compare(to: $0.1) }
            for comparison in comparisons {
                XCTAssert(comparison.isSame, String(describing: comparison))
            }

            XCTAssertEqual(bodyData.includes.count, expectedIncludes.count)

            let includeComparisons = zip(bodyData.includes.values.compactMap(\.c), expectedIncludes).map { $0.0.compare(to: $0.1) }
            for comparison in includeComparisons {
                XCTAssert(comparison.isSame, String(describing: comparison))
            }
        }
    }

    func test_indexEndpoint_populatedResultWithPropertiesIncluded_succeeds() throws {
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

        let testDescriptors = [
            try DB.APITestDescriptor(id: UUID(), testProperties: testProperties[0]),
            try DB.APITestDescriptor(id: UUID(), testProperties: testProperties[1])
        ]

        let testMessage = try DB.APITestMessage(
            testDescriptor: testDescriptors[0],
            messageType: .info,
            path: nil,
            context: nil,
            message: "hello world"
        )

        testDatabase.append([
            TestOutput(testDescriptors[0]),
            TestOutput(testDescriptors[1])
        ])
        // expect a query for properties
        testDatabase.append([
            TestOutput(testProperties[0]),
            TestOutput(testProperties[1])
        ])
        // expect a query for messages because that is a to-many relationship
        // so we need to query for them even if they are not being included.
        testDatabase.append([
            TestOutput(testMessage)
        ])

        app.databases.use(testDatabase.configuration, as: .psql)

        let testController = APITestController(
            outputPath: FileManager.default.temporaryDirectory.absoluteString,
            openAPISource: nil
        )

        testController.mount(on: app, at: "api_tests")

        let expectedValues = [
            API.APITestDescriptor(
                id: .init(rawValue: testDescriptors[0].id!),
                attributes: .init(createdAt: testDescriptors[0].createdAt, finishedAt: testDescriptors[0].finishedAt, status: testDescriptors[0].status),
                relationships: .init(testPropertiesId: .init(rawValue: testProperties[0].id!), messageIds: [.init(rawValue: testMessage.id!)]),
                meta: .none,
                links: .none
            ),
            API.APITestDescriptor(
                id: .init(rawValue: testDescriptors[1].id!),
                attributes: .init(createdAt: testDescriptors[1].createdAt, finishedAt: testDescriptors[1].finishedAt, status: testDescriptors[1].status),
                relationships: .init(testPropertiesId: .init(rawValue: testProperties[1].id!), messageIds: []),
                meta: .none,
                links: .none
            )
        ]

        let expectedIncludes: [API.BatchAPITestDescriptorDocument.Include] = [
            .init(
                API.APITestProperties(
                    id: .init(rawValue: testProperties[0].id!),
                    attributes: .init(
                        createdAt: testProperties[0].createdAt,
                        apiHostOverride: testProperties[0].apiHostOverride,
                        parser: .stable
                    ),
                    relationships: .init(openAPISourceId: .init(rawValue: testProperties[0].$openAPISource.id)),
                    meta: .none,
                    links: .none
                )
            ),
            .init(
                API.APITestMessage(
                    id: .init(rawValue: testMessage.id!),
                    attributes: .init(
                        createdAt: testMessage.createdAt,
                        messageType: testMessage.messageType,
                        path: testMessage.path,
                        context: testMessage.context,
                        message: testMessage.message
                    ),
                    relationships: .init(apiTestDescriptorId: .init(rawValue: testMessage.$apiTestDescriptor.id)),
                    meta: .none,
                    links: .none
                )
            ),
            .init(
                API.APITestProperties(
                    id: .init(rawValue: testProperties[1].id!),
                    attributes: .init(
                        createdAt: testProperties[1].createdAt,
                        apiHostOverride: testProperties[1].apiHostOverride,
                        parser: .fast
                    ),
                    relationships: .init(openAPISourceId: .init(rawValue: testProperties[1].$openAPISource.id)),
                    meta: .none,
                    links: .none
                )
            )
        ]

        try app.testable().test(.GET, "api_tests?include=messages,testProperties") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok, "with body: \(res.body.string)")

            let body = try res.content.decode(API.BatchAPITestDescriptorDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparisons = zip(bodyData.primary.values, expectedValues).map { $0.0.compare(to: $0.1) }
            for comparison in comparisons {
                XCTAssert(comparison.isSame, String(describing: comparison))
            }

            XCTAssertEqual(bodyData.includes.count, expectedIncludes.count)

            let includeComparison = bodyData.includes.compare(to: .init(values: expectedIncludes))
            XCTAssert(includeComparison.isSame, String(describing: includeComparison))
        }
    }

    func test_indexEndpoint_populatedResultWithSourceIncluded_succeeds() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        let openAPISourceUUIDs = [
            UUID(),
            UUID()
        ]

        let testSources = [
            DB.OpenAPISource(
                id: openAPISourceUUIDs[0],
                uri: "http://website.com/that.json",
                sourceType: .url
            ),
            DB.OpenAPISource(
                id: openAPISourceUUIDs[1],
                uri:"/Users/john/file.yml",
                sourceType: .filepath
            )
        ]

        let testProperties = [
            DB.APITestProperties(openAPISourceId: openAPISourceUUIDs[0], apiHostOverride: nil, parser: .stable),
            DB.APITestProperties(openAPISourceId: openAPISourceUUIDs[1], apiHostOverride: URL(string: "http://website.com")!, parser: .fast)
        ]

        let testDescriptors = [
            try DB.APITestDescriptor(id: UUID(), testProperties: testProperties[0]),
            try DB.APITestDescriptor(id: UUID(), testProperties: testProperties[1])
        ]

        let testMessage = try DB.APITestMessage(
            testDescriptor: testDescriptors[0],
            messageType: .info,
            path: nil,
            context: nil,
            message: "hello world"
        )

        testDatabase.append([
            TestOutput(testDescriptors[0]),
            TestOutput(testDescriptors[1])
        ])
        // expect a query for properties
        testDatabase.append([
            TestOutput(testProperties[0]),
            TestOutput(testProperties[1])
        ])
        // expect a query for sources
        testDatabase.append([
            TestOutput(testSources[0]),
            TestOutput(testSources[1])
        ])
        // expect a query for messages because that is a to-many relationship
        // so we need to query for them even if they are not being included.
        testDatabase.append([
            TestOutput(testMessage)
        ])

        app.databases.use(testDatabase.configuration, as: .psql)

        let testController = APITestController(
            outputPath: FileManager.default.temporaryDirectory.absoluteString,
            openAPISource: nil
        )

        testController.mount(on: app, at: "api_tests")

        let expectedValues = [
            API.APITestDescriptor(
                id: .init(rawValue: testDescriptors[0].id!),
                attributes: .init(createdAt: testDescriptors[0].createdAt, finishedAt: testDescriptors[0].finishedAt, status: testDescriptors[0].status),
                relationships: .init(testPropertiesId: .init(rawValue: testProperties[0].id!), messageIds: [.init(rawValue: testMessage.id!)]),
                meta: .none,
                links: .none
            ),
            API.APITestDescriptor(
                id: .init(rawValue: testDescriptors[1].id!),
                attributes: .init(createdAt: testDescriptors[1].createdAt, finishedAt: testDescriptors[1].finishedAt, status: testDescriptors[1].status),
                relationships: .init(testPropertiesId: .init(rawValue: testProperties[1].id!), messageIds: []),
                meta: .none,
                links: .none
            )
        ]

        let expectedIncludes: [API.BatchAPITestDescriptorDocument.Include] = [
            .init(
                API.APITestProperties(
                    id: .init(rawValue: testProperties[0].id!),
                    attributes: .init(
                        createdAt: testProperties[0].createdAt,
                        apiHostOverride: testProperties[0].apiHostOverride,
                        parser: .stable
                    ),
                    relationships: .init(openAPISourceId: .init(rawValue: testProperties[0].$openAPISource.id)),
                    meta: .none,
                    links: .none
                )
            ),
            .init(
                API.OpenAPISource(
                    id: .init(rawValue: testSources[0].id!),
                    attributes: .init(
                        createdAt: testSources[0].createdAt,
                        uri: testSources[0].uri,
                        sourceType: testSources[0].sourceType
                    ),
                    relationships: .none,
                    meta: .none,
                    links: .none
                )
            ),
            .init(
                API.APITestMessage(
                    id: .init(rawValue: testMessage.id!),
                    attributes: .init(
                        createdAt: testMessage.createdAt,
                        messageType: testMessage.messageType,
                        path: testMessage.path,
                        context: testMessage.context,
                        message: testMessage.message
                    ),
                    relationships: .init(apiTestDescriptorId: .init(rawValue: testMessage.$apiTestDescriptor.id)),
                    meta: .none,
                    links: .none
                )
            ),
            .init(
                API.APITestProperties(
                    id: .init(rawValue: testProperties[1].id!),
                    attributes: .init(
                        createdAt: testProperties[1].createdAt,
                        apiHostOverride: testProperties[1].apiHostOverride,
                        parser: .fast
                    ),
                    relationships: .init(openAPISourceId: .init(rawValue: testProperties[1].$openAPISource.id)),
                    meta: .none,
                    links: .none
                )
            ),
            .init(
                API.OpenAPISource(
                    id: .init(rawValue: testSources[1].id!),
                    attributes: .init(
                        createdAt: testSources[1].createdAt,
                        uri: testSources[1].uri,
                        sourceType: testSources[1].sourceType
                    ),
                    relationships: .none,
                    meta: .none,
                    links: .none
                )
            )
        ]

        try app.testable().test(.GET, "api_tests?include=messages,testProperties,testProperties.openAPISource") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok, "with body: \(res.body.string)")

            let body = try res.content.decode(API.BatchAPITestDescriptorDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparisons = zip(bodyData.primary.values, expectedValues).map { $0.0.compare(to: $0.1) }
            for comparison in comparisons {
                XCTAssert(comparison.isSame, String(describing: comparison))
            }

            XCTAssertEqual(bodyData.includes.count, expectedIncludes.count)

            let includeComparison = bodyData.includes.compare(to: .init(values: expectedIncludes))
            XCTAssert(includeComparison.isSame, String(describing: includeComparison))
        }
    }

    func test_showEndpoint_malformedId_fails() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testController = APITestController(
            outputPath: FileManager.default.temporaryDirectory.absoluteString,
            openAPISource: nil
        )

        testController.mount(on: app, at: "api_tests")

        try app.testable().test(.GET, "api_tests/1234") { res in
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

        let testController = APITestController(
            outputPath: FileManager.default.temporaryDirectory.absoluteString,
            openAPISource: nil
        )

        testController.mount(on: app, at: "api_tests")

        try app.testable().test(.GET, "api_tests/B40806D3-B71E-4626-9878-0DE98EFC6CEC") { res in
            XCTAssertEqual(res.status, HTTPStatus.notFound)
        }
    }

    func test_showEndpoint_foundResult_succeeds() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        let testDescriptor = try DB.APITestDescriptor(
            id: UUID(),
            testProperties: .init(openAPISourceId: UUID(), apiHostOverride: nil, parser: .stable)
        )

        // expect a database query to find the properties resource
        // and respond with a resource
        testDatabase.append([
            TestOutput(testDescriptor)
        ])
        // expect a database query to find the messages because they are a to-many
        // resource even though they are not being included
        testDatabase.append([])

        let testController = APITestController(
            outputPath: FileManager.default.temporaryDirectory.absoluteString,
            openAPISource: nil
        )

        testController.mount(on: app, at: "api_tests")

        let expectedValue = API.APITestDescriptor(
            id: .init(rawValue: testDescriptor.id!),
            attributes: .init(createdAt: testDescriptor.createdAt, finishedAt: testDescriptor.finishedAt, status: testDescriptor.status),
            relationships: .init(testPropertiesId: .init(rawValue: testDescriptor.$testProperties.id), messageIds: []),
            meta: .none,
            links: .none
        )

        try app.testable().test(.GET, "api_tests/\(testDescriptor.id!.uuidString)") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok, "with body: \(res.body.string)")

            let body = try res.content.decode(API.SingleAPITestDescriptorDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparison = bodyData.primary.value.compare(to: expectedValue)
            XCTAssert(comparison.isSame, String(describing: comparison))
            XCTAssertEqual(body.data.includes.values, [])
        }
    }

//    func test_showEndpoint_foundResultWithIncludes_succeeds() throws {
//        let app = try testApp()
//        defer { app.shutdown() }
//
//        app.middleware.use(JSONAPIErrorMiddleware())
//
//        let testDatabase = ArrayTestDatabase()
//
//        app.databases.use(testDatabase.configuration, as: .psql)
//
//        let sourceUUID = UUID()
//        let testProperty = DB.APITestProperties(openAPISourceId: sourceUUID, apiHostOverride: nil)
//        let testSource = DB.OpenAPISource(id: sourceUUID, uri: "http://website.com/source.yml", sourceType: .url)
//
//        // expect a database query to find the properties resource
//        // and respond with a resource
//        testDatabase.append([
//            TestOutput(testProperty)
//        ])
//        // expect a database query to find the related openapi source.
//        testDatabase.append([
//            TestOutput(testSource)
//        ])
//
//        let propertiesController = APITestPropertiesController(
//            openAPISource: nil
//        )
//
//        propertiesController.mount(on: app, at: "api_test_properties")
//
//        let expectedPrimary = API.APITestProperties(
//            id: .init(rawValue: testProperty.id!),
//            attributes: .init(createdAt: testProperty.createdAt, apiHostOverride: testProperty.apiHostOverride),
//            relationships: .init(openAPISource: .init(id: .init(rawValue: sourceUUID))),
//            meta: .none,
//            links: .none
//        )
//
//        let expectedInclude = API.OpenAPISource(
//            id: .init(rawValue: sourceUUID),
//            attributes: .init(
//                createdAt: testSource.createdAt,
//                uri: testSource.uri,
//                sourceType: testSource.sourceType
//            ),
//            relationships: .none,
//            meta: .none,
//            links: .none
//        )
//
//        try app.testable().test(.GET, "api_test_properties/\(testProperty.id!.uuidString)?include=openAPISource") { res in
//            XCTAssertEqual(res.status, HTTPStatus.ok, "with body:\n\(res.body.string)")
//
//            let body = try res.content.decode(API.SingleAPITestPropertiesDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))
//
//            let bodyData = try XCTUnwrap(body.data)
//            let comparison = bodyData.primary.value.compare(to: expectedPrimary)
//            XCTAssert(comparison.isSame, String(describing: comparison))
//            let includeComparison = bodyData.includes.values[0].a?.compare(to: expectedInclude)
//            XCTAssert(includeComparison?.isSame ?? false, String(describing: includeComparison))
//        }
//    }
}
