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

// MARK: - Queues Vars
public extension Environment {
    static func redisURL() throws -> String {
        guard let url = Environment.get("API_TEST_REDIS_URL") else {
            throw RedisError.invalidUrl("Not Set")
        }
        return url
    }

    enum RedisError: Swift.Error {
        case invalidUrl(String)
    }

    /// `true` if the Jobs Queue should be started
    /// in the same process as the server. By default,
    /// this is false and jobs are expected to be processed
    /// by a queues service in its own process.
    static var inProcessJobs: Bool {
        return Environment.get("API_TEST_IN_PROCESS_QUEUES") == "true"
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
