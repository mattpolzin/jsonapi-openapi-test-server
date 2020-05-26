//
//  APITestProperties+API.swift
//  
//
//  Created by Mathew Polzin on 4/29/20.
//

import Foundation
import APIModels
import Fluent
import Vapor
import OpenAPIReflection
import JSONAPI

extension API {

    static func batchAPITestPropertiesResponse(query: QueryBuilder<DB.APITestProperties>, includeSource: Bool) -> EventLoopFuture<BatchAPITestPropertiesDocument.SuccessDocument> {

        if includeSource {
            query.with(\.$openAPISource)
        }

        let primaryFuture = query.all()

        let resourcesFuture = primaryFuture.flatMapThrowing { descriptors in try descriptors.map { try $0.jsonApiResources() } }

        let responseFuture = resourcesFuture
            .map(BatchAPITestPropertiesDocument.SuccessDocument.init)

        return responseFuture
    }

    /// Pass a query builder where the first result will be used.
    static func singleAPITestPropertiesResponse(query: QueryBuilder<DB.APITestProperties>, includeSource: Bool) -> EventLoopFuture<SingleAPITestPropertiesDocument.SuccessDocument> {

        if includeSource {
            query.with(\.$openAPISource)
        }

        let primaryFuture = query.first()

        let resourceFuture = primaryFuture.flatMapThrowing { try $0?.jsonApiResources() }
            .unwrap(or: Abort(.notFound))

        let responseFuture = resourceFuture
            .map(SingleAPITestPropertiesDocument.SuccessDocument.init)

        return responseFuture
    }
}

fileprivate typealias SerializedTestProperties = (properties: API.APITestProperties, source: API.OpenAPISource?)

fileprivate func sourceIncludes(from serializedDescriptor: SerializedTestProperties) -> [API.BatchAPITestPropertiesDocument.Include] {
    return serializedDescriptor.source
        .map(API.BatchAPITestPropertiesDocument.Include.init).map { [$0] } ?? []
}
