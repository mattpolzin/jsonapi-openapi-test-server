//
//  APITestEnvironment+server.swift
//  App
//
//  Created by Mathew Polzin on 9/28/19.
//

import Foundation
import PostgresKit
import Vapor

// MARK: - Database Vars
public extension Environment {
    /// Required Postgres URL.
    static func dbConfig() throws -> PostgresConfiguration {
        let envVar = Environment.get("API_TEST_DATABASE_URL")
        guard let config = envVar
            .flatMap(URL.init(string:))
            .flatMap(PostgresConfiguration.init(url:)) else {
                throw DatabaseError.invalidUrl(envVar ?? "Not Set")
        }
        return config
    }

    enum DatabaseError: Swift.Error {
        case invalidUrl(String)
    }
}

// MARK: - Archive Vars
public extension Environment {
    /// Optional Archives path (folder location in which zip archives will be stored).
    static var archivesPath: String {
        let defaultDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("api_test_archives")
            .path

        return Environment.get("API_TEST_ARCHIVES_PATH") ?? defaultDir
    }
}
