//
//  APITestProperties.swift
//  
//
//  Created by Mathew Polzin on 5/2/20.
//

import Foundation
import JSONAPISwiftGen

public struct APITestProperties {
    let apiHostOverride: URL?
    let openAPISource: OpenAPISource
    /// `true` by default, `false` to not
    /// run code formatting on the Swift code
    /// generated for the test suite.
    let formatGeneratedSwift: Bool
    /// Perform validation & linting on the OpenAPI
    /// documentation in addition to generating tests from it.
    let validateOpenAPI: Bool

    public init(
        openAPISource: OpenAPISource,
        apiHostOverride: URL?,
        formatGeneratedSwift: Bool = true,
        validateOpenAPI: Bool = false
    ) {
        self.apiHostOverride = apiHostOverride
        self.openAPISource = openAPISource
        self.formatGeneratedSwift = formatGeneratedSwift
        self.validateOpenAPI = validateOpenAPI
    }
}

extension APITestProperties {
    public var testSuiteConfiguration: JSONAPISwiftGen.TestSuiteConfiguration {
        return .init(apiHostOverride: apiHostOverride)
    }
}
