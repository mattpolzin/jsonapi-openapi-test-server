//
//  InitAPITestDescriptorMigration.swift
//  App
//
//  Created by Mathew Polzin on 9/23/19.
//

import Fluent
import PostgresKit

public struct InitAPITestDescriptorMigration: Migration {
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        
        let statusDataTypeFuture: EventLoopFuture<DatabaseSchema.DataType>

        if let sqlDb = database as? SQLDatabase,
            sqlDb.dialect.enumSyntax == .typeName {
            
            statusDataTypeFuture = sqlDb.create(enum: "TEST_STATUS")
                .value("pending")
                .value("building")
                .value("running")
                .value("passed")
                .value("failed")
                .run()
                .map { .custom("\"TEST_STATUS\"") }
        } else {
            statusDataTypeFuture = database.eventLoop.makeSucceededFuture(.string)
        }

        return statusDataTypeFuture.flatMap { statusDataType in
            database.schema(DB.APITestDescriptor.schema)
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
                    "finished_at",
                    .datetime
            )
                .field(
                    "status",
                    statusDataType,
                    .required
            )
                .field(
                    "openapi_source_id",
                    .uuid,
                    .required,
                    .references(
                        DB.OpenAPISource.schema,
                        "id",
                        onDelete: .restrict,
                        onUpdate: .cascade
                    )
            )
                .create()
        }
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(DB.APITestDescriptor.schema).delete().flatMap {
            if let sqlDb = database as? SQLDatabase,
                sqlDb.dialect.enumSyntax == .typeName {
                return sqlDb.drop(enum: "TEST_STATUS").run()
            }
            return database.eventLoop.makeSucceededFuture(())
        }
    }
}
