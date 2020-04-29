//
//  InitAPITestDescriptorMigration.swift
//  App
//
//  Created by Mathew Polzin on 9/23/19.
//

import Fluent

public struct APITestDescriptorMigration_Init: Migration {
    public func prepare(on database: Database) -> EventLoopFuture<Void> {

        let statusTypeFuture = database.enum("TEST_STATUS")
            .case("pending")
            .case("building")
            .case("running")
            .case("passed")
            .case("failed")
            .create()

        return statusTypeFuture.flatMap { statusDataType in
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
                    "test_properties_id",
                    .uuid,
                    .required,
                    .references(
                        DB.APITestProperties.schema,
                        "id",
                        onDelete: .restrict,
                        onUpdate: .cascade
                    )
            )
                .create()
        }
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(DB.APITestDescriptor.schema).delete()
            .flatMap { database.enum("TEST_STATUS").delete() }
    }
}
