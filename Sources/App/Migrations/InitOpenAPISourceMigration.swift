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

        let sourceDataTypeFuture: EventLoopFuture<DatabaseSchema.DataType>

        if let sqlDb = database as? SQLDatabase,
            sqlDb.dialect.enumSyntax == .typeName {

            sourceDataTypeFuture = sqlDb.create(enum: "SOURCE_TYPE")
                .value("filepath")
                .value("url")
                .run()
                .map { .custom("\"SOURCE_TYPE\"") }
        } else {
            sourceDataTypeFuture = database.eventLoop.makeSucceededFuture(.string)
        }

        return sourceDataTypeFuture.flatMap { sourceDataType in
            database.schema(DB.OpenAPISource.schema)
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
                    sourceDataType,
                    .required
            )
                .unique(on: "uri", "source_type")
                .create()
        }
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(DB.OpenAPISource.schema).delete().flatMap {
            if let sqlDb = database as? SQLDatabase,
                sqlDb.dialect.enumSyntax == .typeName {
                return sqlDb.drop(enum: "SOURCE_TYPE").run()
            }
            return database.eventLoop.makeSucceededFuture(())
        }
    }
}
