//
//  InitOpenAPISourceMigration.swift
//  App
//
//  Created by Mathew Polzin on 12/9/19.
//

import Fluent
import PostgresKit

extension Migration {
    public var name: String {
        return String(reflecting: Self.self)
    }
}

public extension DB.OpenAPISource {
    enum Migrations {
        public struct Create: Migration {
            public func prepare(on database: Database) -> EventLoopFuture<Void> {

                let sourceTypeFuture = database.enum("SOURCE_TYPE")
                    .case("filepath")
                    .case("url")
                    .create()

                return sourceTypeFuture.flatMap { sourceDataType in
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
                return database.schema(DB.OpenAPISource.schema).delete()
                    .flatMap { database.enum("SOURCE_TYPE").delete() }
            }
        }
    }
}
