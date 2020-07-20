//
//  APITestProperties.swift
//  
//
//  Created by Mathew Polzin on 5/2/20.
//

import Foundation
import JSONAPISwiftGen

public enum DecodingStrategy: String, CaseIterable {
    case fast
    case stable
}

public struct APITestProperties {
    let apiHostOverride: URL?
    let openAPISource: OpenAPISource
    /// `true` by default, `false` to not
    /// run code formatting on the Swift code
    /// generated for the test suite.
    let formatGeneratedSwift: Bool
    /// If the test is run against a JSON document,
    /// which strategy should be used. This option
    /// defaults to `.stable` and is not currently used
    /// for YAML decoding.
    let decodingStrategy: DecodingStrategy

    public init(
        openAPISource: OpenAPISource,
        apiHostOverride: URL?,
        formatGeneratedSwift: Bool = true,
        decodingStrategy: DecodingStrategy = .stable
    ) {
        self.apiHostOverride = apiHostOverride
        self.openAPISource = openAPISource
        self.formatGeneratedSwift = formatGeneratedSwift
        self.decodingStrategy = decodingStrategy
    }
}

extension APITestProperties {
    public var testSuiteConfiguration: JSONAPISwiftGen.TestSuiteConfiguration {
        return .init(apiHostOverride: apiHostOverride)
    }
}
