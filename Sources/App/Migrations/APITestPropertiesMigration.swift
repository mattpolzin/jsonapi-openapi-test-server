//
//  APITestPropertiesMigration_Init.swift
//  
//
//  Created by Mathew Polzin on 4/28/20.
//

import Fluent
import PostgresKit
import APIModels

public extension DB.APITestProperties {
    enum Migrations {
        public struct Create: Migration {
            public func prepare(on database: Database) -> EventLoopFuture<Void> {

                return database.schema(DB.APITestProperties.schema)
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
                        "api_host_override",
                        .json
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

            public func revert(on database: Database) -> EventLoopFuture<Void> {
                return database.schema(DB.APITestProperties.schema).delete()
            }
        }
    }
}
