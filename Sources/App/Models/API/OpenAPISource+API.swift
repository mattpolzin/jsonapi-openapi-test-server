//
//  API_OpenAPISource.swift
//  App
//
//  Created by Mathew Polzin on 9/23/19.
//

import Foundation
import JSONAPI
import Poly
import Fluent
import Vapor

extension API {
    public enum OpenAPISourceDescription: JSONAPI.ResourceObjectDescription {
        public static let jsonType: String = "openapi_source"

        public struct Attributes: JSONAPI.SparsableAttributes {
            public let createdAt: Attribute<Date>
            public let uri: Attribute<String>
            public let sourceType: Attribute<DB.OpenAPISource.SourceType>

            public init(createdAt: Date,
                        uri: String,
                        sourceType: DB.OpenAPISource.SourceType) {
                self.createdAt = .init(value: createdAt)
                self.uri = .init(value: uri)
                self.sourceType = .init(value: sourceType)
            }

            public enum CodingKeys: SparsableCodingKey {
                case createdAt
                case uri
                case sourceType
            }
        }

        public typealias Relationships = NoRelationships
    }

    public typealias OpenAPISource = JSONAPI.ResourceObject<OpenAPISourceDescription, NoMetadata, NoLinks, UUID>
    public typealias NewOpenAPISource = JSONAPI.ResourceObject<OpenAPISourceDescription, NoMetadata, NoLinks, Unidentified>

    public typealias BatchOpenAPISourceDocument = BatchDocument<OpenAPISource, NoIncludes>

    public typealias SingleOpenAPISourceDocument = SingleDocument<OpenAPISource, NoIncludes>

    public typealias CreateOpenAPISourceDocument = SingleDocument<NewOpenAPISource, NoIncludes>

    static func batchOpenAPISourceResponse(query: QueryBuilder<DB.OpenAPISource>) -> EventLoopFuture<BatchOpenAPISourceDocument.SuccessDocument> {

        let primaryFuture = query.all()

        let resourcesFuture: EventLoopFuture<[OpenAPISource]> = primaryFuture
            .flatMapThrowing {
                try $0.map { openAPISource -> OpenAPISource in
                    try openAPISource.serializable()
                }
        }

        let responseFuture = resourcesFuture.map { resources in
            BatchOpenAPISourceDocument.SuccessDocument(apiDescription: .none,
                                                       body: .init(resourceObjects: resources),
                                                       includes: .none,
                                                       meta: .none,
                                                       links: .none)
        }

        return responseFuture
    }

    /// Pass a query builder where the first result will be used.
    static func singleOpenAPISourceResponse(query: QueryBuilder<DB.OpenAPISource>) -> EventLoopFuture<SingleOpenAPISourceDocument.SuccessDocument> {

        let primaryFuture = query.first()

        let resourceFuture = primaryFuture
            .flatMapThrowing {
                try $0?.serializable()
        }.unwrap(or: Abort(.notFound))

        let responseFuture = resourceFuture
            .map { resource in
                SingleOpenAPISourceDocument.SuccessDocument(apiDescription: .none,
                                                            body: .init(resourceObject: resource),
                                                            includes: .none,
                                                            meta: .none,
                                                            links: .none)
        }

        return responseFuture
    }
}
