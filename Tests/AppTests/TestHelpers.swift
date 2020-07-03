//
//  TestHelpers.swift
//  
//
//  Created by Mathew Polzin on 5/2/20.
//

import Vapor
import Fluent
import XCTFluent

func testApp(stackTrace: Bool = false) throws -> Application {
    StackTrace.isCaptureEnabled = stackTrace
    return Application(.testing)
}
