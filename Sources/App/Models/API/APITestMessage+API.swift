//
//  APITestMessage+API.swift
//  
//
//  Created by Mathew Polzin on 4/22/20.
//

import Foundation
import APIModels
import Fluent
import Vapor
import OpenAPIReflection
import JSONAPI

extension API {
    /// Pass a query builder where the first result will be used.
    static func singleAPITestMessageResponse(query: QueryBuilder<DB.APITestMessage>) -> EventLoopFuture<SingleAPITestMessageDocument.SuccessDocument> {

        let primaryFuture = query.first()

        let resourceFuture = primaryFuture
            .flatMapThrowing { message -> APITestMessage? in
                try message.map { try $0.serializable() }
        }.unwrap(or: Abort(.notFound))

        let responseFuture = resourceFuture
            .map { resource in
                SingleAPITestMessageDocument.SuccessDocument(
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

extension API.MessageType: AnyJSONCaseIterable {}
