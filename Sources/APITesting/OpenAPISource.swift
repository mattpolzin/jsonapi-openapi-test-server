//
//  OpenAPISource.swift
//  
//
//  Created by Mathew Polzin on 3/8/20.
//

import Vapor

public enum OpenAPISource {
    case file(path: String)
    case unauthenticated(url: URI)
    case basicAuth(url: URI, username: String, password: String)

    public enum Error: Swift.Error, CustomStringConvertible {
        case noInputSpecified
        case fileReadError(String)

        public var description: String {
            switch self {
            case .noInputSpecified:
                return "No OpenAPI input source was specified."
            case .fileReadError(let error):
                return "Failed to read OpenAPI file with error: \(error)"
            }
        }
    }
}
