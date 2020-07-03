//
//  OpenAPISource.swift
//  
//
//  Created by Mathew Polzin on 3/8/20.
//

import Vapor
import OpenAPIKit

public enum OpenAPISource {
    case file(path: String)
    case unauthenticated(url: URI)
    case basicAuth(url: URI, username: String, password: String)

    public enum Error: Swift.Error, CustomStringConvertible {
        case noInputSpecified
        case fileReadError(Swift.Error)

        public var description: String {
            switch self {
            case .noInputSpecified:
                return "No OpenAPI input source was specified."
            case .fileReadError(let error):
                let prettyError = OpenAPI.Error(from: error)
                return "Failed to read OpenAPI file with error: \(prettyError.localizedDescription) (full path: \(prettyError.codingPathString))"
            }
        }
    }
}
