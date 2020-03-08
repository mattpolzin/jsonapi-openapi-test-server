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

    public enum Error: Swift.Error {
        case noInputSpecified
        case fileReadError(String)
    }
}
