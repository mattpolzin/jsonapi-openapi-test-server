//
//  OpenAPISource+detect.swift
//  App
//
//  Created by Mathew Polzin on 9/28/19.
//

import Foundation
import SwiftGen
import Vapor

public extension OpenAPISource {
    static func detect() throws -> OpenAPISource {
        if let path = Environment.inFile {
            return .file(path: path)
        }

        if let url = Environment.inUrl.map(URI.init(string:)) {

            if let (username, password) = try Environment.credentials() {
                return .basicAuth(url: url, username: username, password: password)
            }

            return .unauthenticated(url: url)
        }

        throw Error.noInputSpecified
    }
}
