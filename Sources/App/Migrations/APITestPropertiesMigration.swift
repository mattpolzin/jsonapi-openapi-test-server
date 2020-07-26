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
        public struct AddParserField: Migration {
            public func prepare(on database: Database) -> EventLoopFuture<Void> {
                let parserTypeFuture = database.enum("PARSER")
                    .case("fast")
                    .case("stable")
                    .create()

                return parserTypeFuture.flatMap { parserDataType in
                    // no fluent support as of now for adding
                    // a required field with a default value
                    // or retrofilling existing rows and then
                    // setting to required after the fact
                    database.schema(DB.APITestProperties.schema) // create as optional
                    .field(
                        "parser",
                        parserDataType
                    )
                    .update()
                    .flatMap { // backfill as stable
                        database.query(DB.APITestProperties.self)
                            .set(\.$parser, to: API.Parser.stable)
                            .update()
                    }
                    .flatMap { // update to non-optional
                        (database as! PostgresDatabase)
                            .query("ALTER TABLE \(DB.APITestProperties.schema) ALTER COLUMN parser SET NOT NULL")
                            .transform(to: ())
                    }
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
