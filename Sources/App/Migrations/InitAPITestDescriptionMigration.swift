//
//  InitAPITestDescriptionMigration.swift
//  App
//
//  Created by Mathew Polzin on 9/23/19.
//

import Fluent

public struct InitAPITestDescriptorMigration: Migration {
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(DB.APITestDescriptor.schema)
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
            .string,
            .required
        )
        .field(
            "openapi_source_id",
            .uuid,
            .required,
            .foreignKey(
                field: .string(schema: DB.OpenAPISource.schema, field: "id"),
                onDelete: .restrict,
                onUpdate: .cascade
            )
        )
        .create()
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(DB.APITestDescriptor.schema).delete()
    }
}
