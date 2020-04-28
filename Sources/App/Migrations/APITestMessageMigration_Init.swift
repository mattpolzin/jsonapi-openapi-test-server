//
//  InitAPITestMessageMigration.swift
//  App
//
//  Created by Mathew Polzin on 9/23/19.
//

import Fluent
import PostgresKit

public struct APITestMessageMigration_Init: Migration {
    public func prepare(on database: Database) -> EventLoopFuture<Void> {

        let messageTypeFuture = database.enum("MESSAGE_TYPE")
            .case("debug")
            .case("info")
            .case("warning")
            .case("success")
            .case("error")
            .create()

        return messageTypeFuture.flatMap { messageDataType in
            database.schema(DB.APITestMessage.schema)
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
                    messageDataType,
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
                    .references(
                        DB.APITestDescriptor.schema,
                        "id",
                        onDelete: .cascade,
                        onUpdate: .cascade
                    )
            )
                .create()
        }
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(DB.APITestMessage.schema).delete()
            .flatMap { database.enum("MESSAGE_TYPE").delete() }
    }
}
