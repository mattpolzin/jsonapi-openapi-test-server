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

    // TODO: uncomment and finish tests

//    func test_indexEndpoint_emptyResult_succeeds() throws {
//        let app = Application(.testing)
//        defer { app.shutdown() }
//
//        app.middleware.use(JSONAPIErrorMiddleware())
//
//        let testDatabase = ArrayTestDatabase()
//
//        testDatabase.append([])
//
//        app.databases.use(testDatabase.configuration, as: .psql)
//
//        let propertiesController = APITestPropertiesController(
//            openAPISource: nil
//        )
//
//        propertiesController.mount(on: app, at: "api_test_properties")
//
//        try app.testable().test(.GET, "api_test_properties") { res in
//            XCTAssertEqual(res.status, HTTPStatus.ok)
//
//            let body = try res.content.decode(API.BatchAPITestPropertiesDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))
//
//            XCTAssertEqual(body.data?.primary.values, [])
//            XCTAssertEqual(body.data?.includes.values, [])
//        }
//    }
//
//    func test_indexEndpoint_populatedResult_succeeds() throws {
//        let app = Application(.testing)
//        defer { app.shutdown() }
//
//        app.middleware.use(JSONAPIErrorMiddleware())
//
//        let testDatabase = ArrayTestDatabase()
//
//        let openAPISourceUUIDs = [
//            UUID(),
//            UUID()
//        ]
//
//        let testProperties = [
//            DB.APITestProperties(openAPISourceId: openAPISourceUUIDs[0], apiHostOverride: nil),
//            DB.APITestProperties(openAPISourceId: openAPISourceUUIDs[1], apiHostOverride: URL(string: "http://website.com")!)
//        ]
//
//        testDatabase.append([
//            TestOutput(testProperties[0]),
//            TestOutput(testProperties[1])
//        ])
//
//        app.databases.use(testDatabase.configuration, as: .psql)
//
//        let propertiesController = APITestPropertiesController(
//            openAPISource: nil
//        )
//
//        propertiesController.mount(on: app, at: "api_test_properties")
//
//        let expectedValues = [
//            API.APITestProperties(
//                id: .init(rawValue: testProperties[0].id!),
//                attributes: .init(createdAt: testProperties[0].createdAt, apiHostOverride: testProperties[0].apiHostOverride),
//                relationships: .init(openAPISource: .init(id: .init(rawValue: openAPISourceUUIDs[0]))),
//                meta: .none,
//                links: .none
//            ),
//            API.APITestProperties(
//                id: .init(rawValue: testProperties[1].id!),
//                attributes: .init(createdAt: testProperties[1].createdAt, apiHostOverride: testProperties[1].apiHostOverride),
//                relationships: .init(openAPISource: .init(id: .init(rawValue: openAPISourceUUIDs[1]))),
//                meta: .none,
//                links: .none
//            )
//        ]
//
//        try app.testable().test(.GET, "api_test_properties") { res in
//            XCTAssertEqual(res.status, HTTPStatus.ok)
//
//            let body = try res.content.decode(API.BatchAPITestPropertiesDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))
//
//            let bodyData = try XCTUnwrap(body.data)
//            let comparisons = zip(bodyData.primary.values, expectedValues).map { $0.0.compare(to: $0.1) }
//            for comparison in comparisons {
//                XCTAssert(comparison.isSame, String(describing: comparison))
//            }
//            XCTAssertEqual(body.data?.includes.values, [])
//        }
//    }
//
//    func test_showEnpoint_missingResult_fails() throws {
//        let app = Application(.testing)
//        defer { app.shutdown() }
//
//        app.middleware.use(JSONAPIErrorMiddleware())
//
//        let testDatabase = ArrayTestDatabase()
//
//        app.databases.use(testDatabase.configuration, as: .psql)
//
//        // expect a database query to find the properties resource
//        // and respond with an empty result
//        testDatabase.append([])
//
//        let propertiesController = APITestPropertiesController(
//            openAPISource: nil
//        )
//
//        propertiesController.mount(on: app, at: "api_test_properties")
//
//        try app.testable().test(.POST, "api_test_properties/1234") { res in
//            XCTAssertEqual(res.status, HTTPStatus.notFound)
//        }
//    }
//
//    func test_showEndpoint_foundResult_succeeds() throws {
//        let app = Application(.testing)
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
//
//        // expect a database query to find the properties resource
//        // and respond with a resource
//        testDatabase.append([
//            TestOutput(testProperty)
//        ])
//
//        let propertiesController = APITestPropertiesController(
//            openAPISource: nil
//        )
//
//        propertiesController.mount(on: app, at: "api_test_properties")
//
//        let expectedValue = API.APITestProperties(
//            id: .init(rawValue: testProperty.id!),
//            attributes: .init(createdAt: testProperty.createdAt, apiHostOverride: testProperty.apiHostOverride),
//            relationships: .init(openAPISource: .init(id: .init(rawValue: sourceUUID))),
//            meta: .none,
//            links: .none
//        )
//
//        try app.testable().test(.GET, "api_test_properties/\(testProperty.id!.uuidString)") { res in
//            XCTAssertEqual(res.status, HTTPStatus.ok)
//
//            let body = try res.content.decode(API.SingleAPITestPropertiesDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))
//
//            let bodyData = try XCTUnwrap(body.data)
//            let comparison = bodyData.primary.value.compare(to: expectedValue)
//            XCTAssert(comparison.isSame, String(describing: comparison))
//            XCTAssertEqual(body.data?.includes.values, [])
//        }
//    }
}
