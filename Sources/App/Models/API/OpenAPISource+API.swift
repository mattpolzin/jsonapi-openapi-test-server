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
import JSONAPI

extension API {
    static func batchOpenAPISourceResponse(query: QueryBuilder<DB.OpenAPISource>) -> EventLoopFuture<BatchOpenAPISourceDocument.SuccessDocument> {

        let primaryFuture = query.all()

        let resourcesFuture = primaryFuture
            .flatMapThrowing { sources in try sources.map { try $0.jsonApiResources() } }

        let responseFuture = resourcesFuture.map { $0.map(\.primary) }
            .map(ManyResourceBody.init)
            .map(BatchOpenAPISourceDocument.SuccessDocument.init)

        return responseFuture
    }

    /// Pass a query builder where the first result will be used.
    static func singleOpenAPISourceResponse(query: QueryBuilder<DB.OpenAPISource>) -> EventLoopFuture<SingleOpenAPISourceDocument.SuccessDocument> {

        let primaryFuture = query.first()

        let resourceFuture = primaryFuture.flatMapThrowing { try $0?.jsonApiResources() }
            .unwrap(or: Abort(.notFound))

        let responseFuture = resourceFuture.map(\.primary)
            .map(SingleResourceBody.init)
            .map(SingleOpenAPISourceDocument.SuccessDocument.init)

        return responseFuture
    }
}
