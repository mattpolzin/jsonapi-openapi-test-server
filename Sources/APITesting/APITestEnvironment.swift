//
//  APITestEnvironment.swift
//  App
//
//  Created by Mathew Polzin on 9/22/19.
//

import Foundation
import Vapor

// MARK: - OpenAPI Documentation Vars
public extension Environment {

    /// Use one of [inFile, inUrl] depending on whether you want to load the OpenAPI Documentaion from
    /// the local filesystem or a remote URL.
    static var inFile: String? {
        Environment.get("API_TEST_IN_FILE")
    }

    /// Use one of [inFile, inUrl] depending on whether you want to load the OpenAPI Documentaion from
    /// the local filesystem or a remote URL.
    static var inUrl: String? {
        Environment.get("API_TEST_IN_URL")
    }

    /// Specify credentials if you need to use basic auth to retrieve the OpenAPI Documentation from a
    /// remote URL.
    ///
    /// - Important: Ignored if reading from `inFile` and not necessary if `inUrl` is not
    ///     password protected.
    static func credentials() throws -> (username: String, password: String)? {

        let username = Environment.get("API_TEST_USERNAME")
        let password = Environment.get("API_TEST_PASSWORD")

        if let un = username, let pw = password {
            return (username: un, password: pw)
        }

        if username != nil { throw CredentialsError.passwordNotSpecified }
        if password != nil { throw CredentialsError.usernameNotSpecified }

        return nil
    }

    enum CredentialsError: Swift.Error {
        case passwordNotSpecified
        case usernameNotSpecified
    }
}

// MARK: - Filesystem Vars
public extension Environment {
    /// Specify the location on the local file system where test files will be written.
    /// If not specified, `~/api_test` will be used.
    static var outPath: String {
        let defaultDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("api_test")
            .path

        return Environment.get("API_TEST_OUT_PATH") ?? defaultDir
    }
}
