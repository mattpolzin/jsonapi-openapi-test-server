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

        let messageDataTypeFuture: EventLoopFuture<DatabaseSchema.DataType>

        if let sqlDb = database as? SQLDatabase,
            sqlDb.dialect.enumSyntax == .typeName {
            
            messageDataTypeFuture = sqlDb.create(enum: "MESSAGE_TYPE")
                .value("debug")
                .value("info")
                .value("warning")
                .value("success")
                .value("error")
                .run()
                .map { .custom("\"MESSAGE_TYPE\"") }
        } else {
            messageDataTypeFuture = database.eventLoop.makeSucceededFuture(.string)
        }

        return messageDataTypeFuture.flatMap { messageDataType in
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
        return database.schema(DB.APITestMessage.schema).delete().flatMap {
            if let sqlDb = database as? SQLDatabase,
                sqlDb.dialect.enumSyntax == .typeName {
                return sqlDb.drop(enum: "MESSAGE_TYPE").run()
            }
            return database.eventLoop.makeSucceededFuture(())
        }
    }
}
