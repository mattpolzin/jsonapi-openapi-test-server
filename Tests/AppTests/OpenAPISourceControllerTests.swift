//
//  OpenAPISourceControllerTests.swift
//  
//
//  Created by Mathew Polzin on 5/7/20.
//

import XCTest
import Fluent
import XCTVapor
import XCTFluent

import App
import APITesting
import APIModels

import JSONAPITesting

final class OpenAPISourceControllerTests: XCTestCase {

    func test_createEndpoint_emptyRequestBody_fails() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        try configureDefaults(for: app)
        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        let sourcesController = OpenAPISourceController()

        sourcesController.mount(on: app, at: "openapi_sources")

        try app.testable().test(.POST, "openapi_sources") { res in
            XCTAssertEqual(res.status, HTTPStatus.unprocessableEntity)
        }
    }

    func test_createEndpoint_succeeds() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        // expect the database to be queried to create the source
        // and serve up the created resource
        testDatabase.append([
            TestOutput(DB.OpenAPISource(uri: "/hello/world.json", sourceType: .filepath))
        ])

        let sourcesController = OpenAPISourceController()

        sourcesController.mount(on: app, at: "openapi_sources")

        // create the POST request body
        let requestedNewSource = API.NewOpenAPISource(
            attributes: .init(createdAt: Date(), uri: "/hello/world.json", sourceType: .filepath),
            relationships: .none,
            meta: .none,
            links: .none
        )

        let requestBody = API.CreateOpenAPISourceDocument(
            apiDescription: .none,
            body: .init(resourceObject: requestedNewSource),
            includes: .none,
            meta: .none,
            links: .none
        )

        // make the test request
        try app.testable().test(.POST, "openapi_sources", beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { res in
            XCTAssertEqual(res.status, HTTPStatus.created)
        }
    }

    func test_indexEndpoint_emptyResult_succeeds() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        testDatabase.append([])

        app.databases.use(testDatabase.configuration, as: .psql)

        let sourcesController = OpenAPISourceController()

        sourcesController.mount(on: app, at: "openapi_sources")

        try app.testable().test(.GET, "openapi_sources") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok)

            let body = try res.content.decode(API.BatchOpenAPISourceDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            XCTAssertEqual(body.data?.primary.values, [])
            XCTAssertEqual(body.data?.includes.values, [])
        }
    }

    func test_indexEndpoint_populatedResult_succeeds() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        let testSources = [
            DB.OpenAPISource(uri: "/hello/world.json", sourceType: .filepath),
            DB.OpenAPISource(uri: "https://website.com/hello/world.json", sourceType: .url)
        ]

        testDatabase.append([
            TestOutput(testSources[0]),
            TestOutput(testSources[1])
        ])

        app.databases.use(testDatabase.configuration, as: .psql)

        let sourcesController = OpenAPISourceController()

        sourcesController.mount(on: app, at: "openapi_sources")

        let expectedValues = [
            API.OpenAPISource(
                id: .init(rawValue: testSources[0].id!),
                attributes: .init(createdAt: testSources[0].createdAt, uri: testSources[0].uri, sourceType: testSources[0].sourceType),
                relationships: .none,
                meta: .none,
                links: .none
            ),
            API.OpenAPISource(
                id: .init(rawValue: testSources[1].id!),
                attributes: .init(createdAt: testSources[1].createdAt, uri: testSources[1].uri, sourceType: testSources[1].sourceType),
                relationships: .none,
                meta: .none,
                links: .none
            )
        ]

        try app.testable().test(.GET, "openapi_sources") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok)

            let body = try res.content.decode(API.BatchOpenAPISourceDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparisons = zip(bodyData.primary.values, expectedValues).map { $0.0.compare(to: $0.1) }
            for comparison in comparisons {
                XCTAssert(comparison.isSame, String(describing: comparison))
            }
            XCTAssertEqual(body.data?.includes.values, [])
        }
    }

    func test_showEndpoint_malformedId_fails() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let sourcesController = OpenAPISourceController()

        sourcesController.mount(on: app, at: "openapi_sources")

        // Id should be a UUID, not an integer
        try app.testable().test(.GET, "openapi_sources/1234") { res in
            XCTAssertEqual(res.status, HTTPStatus.badRequest)
        }
    }

    func test_showEndpoint_missingResult_fails() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        // expect a database query to find the properties resource
        // and respond with an empty result
        testDatabase.append([])

        let sourcesController = OpenAPISourceController()

        sourcesController.mount(on: app, at: "openapi_sources")

        try app.testable().test(.GET, "openapi_sources/B40806D3-B71E-4626-9878-0DE98EFC6CEC") { res in
            XCTAssertEqual(res.status, HTTPStatus.notFound)
        }
    }

    func test_showEndpoint_foundResult_succeeds() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        let testSource = DB.OpenAPISource(uri: "/hello/world.json", sourceType: .filepath)

        // expect a database query to find the properties resource
        // and respond with a resource
        testDatabase.append([
            TestOutput(testSource)
        ])

        let sourcesController = OpenAPISourceController()

        sourcesController.mount(on: app, at: "openapi_sources")

        let expectedValue = API.OpenAPISource(
            id: .init(rawValue: testSource.id!),
            attributes: .init(createdAt: testSource.createdAt, uri: testSource.uri, sourceType: testSource.sourceType),
            relationships: .none,
            meta: .none,
            links: .none
        )

        try app.testable().test(.GET, "openapi_sources/\(testSource.id!.uuidString)") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok)

            let body = try res.content.decode(API.SingleOpenAPISourceDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparison = bodyData.primary.value.compare(to: expectedValue)
            XCTAssert(comparison.isSame, String(describing: comparison))
            XCTAssertEqual(body.data?.includes.values, [])
        }
    }
}
