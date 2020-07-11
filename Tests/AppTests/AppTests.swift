//
//  AppTests.swift
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

import JSONAPI
import JSONAPITesting

final class AppTests: XCTestCase {
    func test_sanityCheck() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        app.get("hello") { req in
            return "hello"
        }

        try app.testable().test(.GET, "hello") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok)
        }
    }

    func test_routesAreMounted() throws {
        let app = try testApp()
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        try addRoutes(app, hobbled: true)

        let expectedRoutes = [
            ["POST", "openapi_sources"],
            ["GET", "openapi_sources"],
            ["GET", "openapi_sources", ":id"],

            ["POST", "api_test_properties"],
            ["GET", "api_test_properties"],
            ["GET", "api_test_properties", ":id"],

            ["POST", "api_tests"],
            ["GET", "api_tests"],
            ["GET", "api_tests", ":id"],
            ["GET", "api_tests", ":id", "files"],
            ["GET", "api_tests", ":id", "logs"],

            ["GET", "api_test_messages", ":id"],

            ["GET", "watch"],

            ["GET", "docs"]
        ]

        for path in expectedRoutes {
            XCTAssert(app.routes.all.contains { route in [route.method.rawValue] + route.path.map(\.description) == path })
        }

        // protect against adding routes without adding them to the test
        XCTAssertEqual(app.routes.all.count, expectedRoutes.count)
    }
}
