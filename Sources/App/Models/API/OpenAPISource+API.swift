//
//  File.swift
//  
//
//  Created by Mathew Polzin on 4/8/20.
//

import Foundation
import APIModels
import Fluent
import Vapor

extension API {
    static func batchOpenAPISourceResponse(query: QueryBuilder<DB.OpenAPISource>) -> EventLoopFuture<BatchOpenAPISourceDocument.SuccessDocument> {

        let primaryFuture = query.all()

        let resourcesFuture: EventLoopFuture<[OpenAPISource]> = primaryFuture
            .flatMapThrowing {
                try $0.map { openAPISource -> OpenAPISource in
                    try openAPISource.jsonApiResources().primary
                }
        }

        let responseFuture = resourcesFuture.map { resources in
            BatchOpenAPISourceDocument.SuccessDocument(
                apiDescription: .none,
                body: .init(resourceObjects: resources),
                includes: .none,
                meta: .none,
                links: .none
            )
        }

        return responseFuture
    }

    /// Pass a query builder where the first result will be used.
    static func singleOpenAPISourceResponse(query: QueryBuilder<DB.OpenAPISource>) -> EventLoopFuture<SingleOpenAPISourceDocument.SuccessDocument> {

        let primaryFuture = query.first()

        let resourceFuture = primaryFuture.flatMapThrowing { try $0?.jsonApiResources().primary }
            .unwrap(or: Abort(.notFound))

        let responseFuture = resourceFuture
            .map { resource in
                SingleOpenAPISourceDocument.SuccessDocument(
                    apiDescription: .none,
                    body: .init(resourceObject: resource),
                    includes: .none,
                    meta: .none,
                    links: .none
                )
        }

        return responseFuture
    }
}
