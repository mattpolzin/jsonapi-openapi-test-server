//
//  APITestPropertiesMigration_Init.swift
//  
//
//  Created by Mathew Polzin on 4/28/20.
//

import Fluent

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
        public struct AddParserField: Migration {
            public func prepare(on database: Database) -> EventLoopFuture<Void> {
                let parserTypeFuture = database.enum("PARSER")
                    .case("fast")
                    .case("stable")
                    .create()

                return parserTypeFuture.flatMap { parserDataType in
                    database.schema(DB.APITestProperties.schema)
                        .field(
                            "parser",
                            parserDataType,
                            .required
                        )
                        .update()
                }
            }

            public func revert(on database: Database) -> EventLoopFuture<Void> {
                return database.schema(DB.APITestProperties.schema)
                    .deleteField("parser")
                    .update()
                    .flatMap { database.enum("PARSER").delete() }
            }
        }
    }
}
