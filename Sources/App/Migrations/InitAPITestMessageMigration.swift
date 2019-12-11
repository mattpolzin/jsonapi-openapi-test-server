//
//  InitAPITestMessageMigration.swift
//  App
//
//  Created by Mathew Polzin on 9/23/19.
//

import Fluent
import PostgresKit

public struct InitAPITestMessageMigration: Migration {
    public func prepare(on database: Database) -> EventLoopFuture<Void> {

        return database.schema(DB.APITestMessage.schema)
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
            "message_type",
            .string,
            .required
        )
        .field(
            "path",
            .string
        )
        .field(
            "context",
            .string
        )
        .field(
            "message",
            .string,
            .required
        )
        .field(
            "api_test_descriptor_id",
            .uuid,
            .required,
            .foreignKey(
                field: .string(schema: DB.APITestDescriptor.schema, field: "id"),
                onDelete: .cascade,
                onUpdate: .cascade
            )
        )
        .create()
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(DB.APITestMessage.schema).delete()
    }
}
