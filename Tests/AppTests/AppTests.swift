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

import JSONAPITesting

final class AppTests: XCTestCase {
    func test_sanityCheck() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.middleware.use(JSONAPIErrorMiddleware())

        app.get("hello") { req in
            return "hello"
        }

        try app.testable().test(.GET, "hello") { res in
            XCTAssertEqual(res.status, HTTPStatus.ok)
        }
    }
}
