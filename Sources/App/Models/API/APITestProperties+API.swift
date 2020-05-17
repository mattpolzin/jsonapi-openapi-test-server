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

        let responseFuture = resourcesFuture.map { $0.map(\.primary) }
            .map(ManyResourceBody.init)
            .map(BatchAPITestPropertiesDocument.SuccessDocument.init)

        guard includeSource else {
            return responseFuture
        }

        let includesFuture = resourcesFuture.map { resources in
            Includes(values: resources.flatMap(\.relatives))
        }

        return responseFuture.and(includesFuture).map { (response, includes) in
            response.including(includes)
        }
    }

    /// Pass a query builder where the first result will be used.
    static func singleAPITestPropertiesResponse(query: QueryBuilder<DB.APITestProperties>, includeSource: Bool) -> EventLoopFuture<SingleAPITestPropertiesDocument.SuccessDocument> {

        if includeSource {
            query.with(\.$openAPISource)
        }

        let primaryFuture = query.first()

        let resourceFuture = primaryFuture.flatMapThrowing { try $0?.jsonApiResources() }
            .unwrap(or: Abort(.notFound))

        let responseFuture = resourceFuture.map(\.primary)
            .map(SingleResourceBody.init)
            .map(SingleAPITestPropertiesDocument.SuccessDocument.init)

        guard includeSource else {
            return responseFuture
        }

        let includesFuture = resourceFuture.map(\.relatives).map(Includes.init)

        return responseFuture.and(includesFuture)
            .map { (response, includes) in
                response.including(includes)
        }
    }
}

fileprivate typealias SerializedTestProperties = (properties: API.APITestProperties, source: API.OpenAPISource?)

fileprivate func sourceIncludes(from serializedDescriptor: SerializedTestProperties) -> [API.BatchAPITestPropertiesDocument.Include] {
    return serializedDescriptor.source
        .map(API.BatchAPITestPropertiesDocument.Include.init).map { [$0] } ?? []
}
