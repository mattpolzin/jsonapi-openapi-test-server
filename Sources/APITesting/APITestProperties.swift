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

    public init(openAPISource: OpenAPISource, apiHostOverride: URL?) {
        self.apiHostOverride = apiHostOverride
        self.openAPISource = openAPISource
    }
}

extension APITestProperties {
    public var testSuiteConfiguration: JSONAPISwiftGen.TestSuiteConfiguration {
        return .init(apiHostOverride: apiHostOverride)
    }
}
