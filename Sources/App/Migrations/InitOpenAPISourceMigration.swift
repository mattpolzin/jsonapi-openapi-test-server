//
//  InitOpenAPISourceMigration.swift
//  App
//
//  Created by Mathew Polzin on 12/9/19.
//

import Fluent
import PostgresKit

public struct InitOpenAPISourceMigration: Migration {
    public func prepare(on database: Database) -> EventLoopFuture<Void> {

        return database.schema(DB.OpenAPISource.schema)
        .field(
            "id",
            .uuid,
            .identifier(auto: false)
        )
        .field(
            "created_at",
            .datetime,
            .required
        )
        .field(
            "uri",
            .string,
            .required
        )
        .field(
            "source_type",
            .string,
            .required
        )
        .unique(on: "uri", "source_type")
        .create()
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(DB.OpenAPISource.schema).delete()
    }
}
