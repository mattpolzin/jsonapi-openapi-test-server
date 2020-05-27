//
//  APITestDescriptor+API.swift
//  
//
//  Created by Mathew Polzin on 4/8/20.
//

import Foundation
import APIModels
import Fluent
import Vapor
import OpenAPIReflection
import JSONAPI

extension API {

    static func batchAPITestDescriptorResponse(query: QueryBuilder<DB.APITestDescriptor>, includeProperties: (Bool, alsoIncludeSource: Bool), includeMessages: Bool) -> EventLoopFuture<BatchAPITestDescriptorDocument.SuccessDocument> {

        var query = query

        if includeProperties.0 {
            query.with(\.$testProperties) {
                if includeProperties.alsoIncludeSource {
                    $0.with(\.$openAPISource)
                }
            }
        }

        // we need to request all messages ragardless of whether they will be included so we have access
        // to the IDs for the Test Descriptor to-many relationship.
        query = query.with(\.$messages)

        // we only need to explicitly filter out messages if not included.
        // any other include will be there or not based on whether the query
        // includes it above.
        let includeFilter: (BatchAPITestDescriptorDocument.Include) -> Bool
        if !includeMessages {
            includeFilter = { !($0.value is API.APITestMessage) }
        } else {
            includeFilter = { _ in true }
        }

        let primaryFuture = query.all()

        let resourcesFuture = primaryFuture.flatMapThrowing { descriptors in
            try descriptors.map { try $0.jsonApiResources().filteringRelatives(by: includeFilter) }
        }

        let responseFuture = resourcesFuture
            .map(BatchAPITestDescriptorDocument.SuccessDocument.init)

        return responseFuture
    }

    /// Pass a query builder where the first result will be used.
    static func singleAPITestDescriptorResponse(query: QueryBuilder<DB.APITestDescriptor>, includeProperties: (Bool, alsoIncludeSource: Bool), includeMessages: Bool) -> EventLoopFuture<SingleAPITestDescriptorDocument.SuccessDocument> {

        var query = query

        if includeProperties.0 {
            query.with(\.$testProperties) {
                if includeProperties.alsoIncludeSource {
                    $0.with(\.$openAPISource)
                }
            }
        }

        // we need to request all messages ragardless of whether they will be included so we have access
        // to the IDs for the Test Descriptor to-many relationship.
        query = query.with(\.$messages)

        // we only need to explicitly filter out messages if not included.
        // any other include will be there or not based on whether the query
        // includes it above.
        let includeFilter: (BatchAPITestDescriptorDocument.Include) -> Bool
        if !includeMessages {
            includeFilter = { !($0.value is API.APITestMessage) }
        } else {
            includeFilter = { _ in true }
        }

        let primaryFuture = query.first()

        let resourceFuture = primaryFuture.flatMapThrowing { descriptor in
            try descriptor?.jsonApiResources().filteringRelatives(by: includeFilter)
        }.unwrap(or: Abort(.notFound))

        let responseFuture = resourceFuture
            .map(SingleAPITestDescriptorDocument.SuccessDocument.init)

        return responseFuture
    }
}

extension API.TestStatus: AnyJSONCaseIterable {}

fileprivate typealias SerializedTestDescriptor = (descriptor: API.APITestDescriptor, properties: API.APITestProperties?, source: API.OpenAPISource?, messages: [API.APITestMessage])

fileprivate func propertiesIncludes(from serializedDescriptor: SerializedTestDescriptor) -> [API.BatchAPITestDescriptorDocument.Include] {
    return serializedDescriptor.properties
        .map(API.BatchAPITestDescriptorDocument.Include.init).map { [$0] } ?? []
}

fileprivate func sourceIncludes(from serializedDescriptor: SerializedTestDescriptor) -> [API.BatchAPITestDescriptorDocument.Include] {
    return serializedDescriptor.source
        .map(API.BatchAPITestDescriptorDocument.Include.init).map { [$0] } ?? []
}

fileprivate func messageIncludes(from serializedDescriptor: SerializedTestDescriptor) -> [API.BatchAPITestDescriptorDocument.Include] {
    return serializedDescriptor.messages
        .map(API.BatchAPITestDescriptorDocument.Include.init)
}
