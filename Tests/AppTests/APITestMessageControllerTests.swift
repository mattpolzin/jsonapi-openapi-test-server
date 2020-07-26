//
//  APITestMessageControllerTests.swift
//  AppTests
//
//  Created by Mathew Polzin on 7/10/20.
//

import XCTest
import Fluent
import XCTVapor
import XCTFluent

import App
import APITesting
import APIModels

import JSONAPITesting

final class APITestMessageControllerTests: XCTestCase {

    func test_showEndpoint_malformedId_fails() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        APITestMessageController.mount(on: app, at: "api_test_messages")

        try app.testable().test(.GET, "api_test_messages/1234") { res in
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

        APITestMessageController.mount(on: app, at: "api_test_messages")

        try app.testable().test(.GET, "api_test_messages/B40806D3-B71E-4626-9878-0DE98EFC6CEC") { res in
            XCTAssertEqual(res.status, HTTPStatus.notFound)
        }
    }

    func test_showEndpoint_foundResult_succeeds() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        let testDatabase = ArrayTestDatabase()

        app.databases.use(testDatabase.configuration, as: .psql)

        let properties = DB.APITestProperties(
            openAPISourceId: UUID(),
            apiHostOverride: nil,
            parser: .stable
        )

        let descriptor = try DB.APITestDescriptor(
            id: UUID(),
            testProperties: properties
        )

        let testMessage = try DB.APITestMessage(
            testDescriptor: descriptor,
            messageType: .info,
            path: nil,
            context: nil,
            message: "hello"
        )

        // expect a database query to find the message resource
        // and respond with a resource
        testDatabase.append([
            TestOutput(testMessage)
        ])

        APITestMessageController.mount(on: app, at: "api_test_messages")

        let expectedValue = API.APITestMessage(
            id: .init(rawValue: testMessage.id!),
            attributes: .init(
                createdAt: testMessage.createdAt,
                messageType: .info,
                path: nil,
                context: nil,
                message: "hello"
            ),
            relationships: .init(apiTestDescriptorId: .init(rawValue: descriptor.id!)),
            meta: .none,
            links: .none
        )

        try app.testable().test(.GET, "api_test_messages/\(testMessage.id!.uuidString)") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok)

            let body = try res.content.decode(API.SingleAPITestMessageDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

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

        let properties = DB.APITestProperties(
            openAPISourceId: UUID(),
            apiHostOverride: nil,
            parser: .stable
        )

        let descriptor = try DB.APITestDescriptor(
            id: UUID(),
            testProperties: properties
        )

        let testMessage = try DB.APITestMessage(
            testDescriptor: descriptor,
            messageType: .info,
            path: nil,
            context: nil,
            message: "hello"
        )

        // expect a database query to find the message resource
        // and respond with a resource
        // it will request the message with the descriptor with
        // its messages to fully populate the JSON:API response.]
        testDatabase.append(
            [ TestOutput(testMessage) ]
        )
        testDatabase.append(
            [ TestOutput(descriptor) ]
        )
        testDatabase.append(
            [ TestOutput(testMessage) ]
        )

        APITestMessageController.mount(on: app, at: "api_test_messages")

        let expectedPrimary = API.APITestMessage(
            id: .init(rawValue: testMessage.id!),
            attributes: .init(
                createdAt: testMessage.createdAt,
                messageType: .info,
                path: nil,
                context: nil,
                message: "hello"
            ),
            relationships: .init(apiTestDescriptorId: .init(rawValue: descriptor.id!)),
            meta: .none,
            links: .none
        )

        let expectedInclude = API.APITestDescriptor(
            id: .init(rawValue: descriptor.id!),
            attributes: .init(
                createdAt: descriptor.createdAt,
                finishedAt: descriptor.finishedAt,
                status: descriptor.status
            ),
            relationships: .init(
                testPropertiesId: .init(rawValue: properties.id!),
                messageIds: [.init(rawValue: testMessage.id!)]
            ),
            meta: .none,
            links: .none
        )

        try app.testable().test(.GET, "api_test_messages/\(testMessage.id!.uuidString)?include=apiTestDescriptor") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok, "with body:\n\(res.body.string)")

            let body = try res.content.decode(API.SingleAPITestMessageDocument.SuccessDocument.self, using: JSONDecoder.custom(dates: .iso8601))

            let bodyData = try XCTUnwrap(body.data)
            let comparison = bodyData.primary.value.compare(to: expectedPrimary)
            XCTAssert(comparison.isSame, String(describing: comparison))
            let includeComparison = bodyData.includes.values[0].a?.compare(to: expectedInclude)
            XCTAssert(includeComparison?.isSame ?? false, String(describing: includeComparison))
        }
    }
}
