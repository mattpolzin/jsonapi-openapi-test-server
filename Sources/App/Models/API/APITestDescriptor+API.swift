//
//  JSONAPITestDescriptor.swift
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
    public struct APITestDescriptorDescription: JSONAPI.ResourceObjectDescription {
        public static let jsonType: String = "api_test_descriptor"

        public struct Attributes: JSONAPI.Attributes {
            public let createdAt: Attribute<Date>
            public let finishedAt: Attribute<Date?>
            public let status: Attribute<DB.APITestDescriptor.Status>

            public init(createdAt: Date,
                        finishedAt: Date?,
                        status: DB.APITestDescriptor.Status) {
                self.createdAt = .init(value: createdAt)
                self.finishedAt = .init(value: finishedAt)
                self.status = .init(value: status)
            }
        }

        public struct Relationships: JSONAPI.Relationships {
            public let messages: ToManyRelationship<APITestMessage, NoMetadata, NoLinks>
            public let openAPISource: ToOneRelationship<OpenAPISource, NoMetadata, NoLinks>

            public init(source: OpenAPISource, messages: [APITestMessage]) {
                self.openAPISource = .init(resourceObject: source)
                self.messages = .init(resourceObjects: messages)
            }

            public init(source: OpenAPISource.Pointer, messages: APITestMessage.Pointers) {
                self.openAPISource = source
                self.messages = messages
            }

            public init(sourceId: OpenAPISource.Id, messageIds: [APITestMessage.Id]) {
                self.openAPISource = .init(id: sourceId)
                self.messages = .init(ids: messageIds)
            }
        }
    }

    public typealias APITestDescriptor = JSONAPI.ResourceObject<APITestDescriptorDescription, NoMetadata, NoLinks, UUID>

    public typealias BatchAPITestDescriptorDocument = BatchDocument<APITestDescriptor, Include2<OpenAPISource, APITestMessage>>

    public typealias SingleAPITestDescriptorDocument = SingleDocument<APITestDescriptor, Include2<OpenAPISource, APITestMessage>>

    static func batchAPITestDescriptorResponse(query: QueryBuilder<DB.APITestDescriptor>, includeSource: Bool, includeMessages: Bool) -> EventLoopFuture<BatchAPITestDescriptorDocument.SuccessDocument> {

        var query = query

        if includeSource {
            query = query.with(\.$openAPISource)
        }
        // TODO: fix so that you can not include messages but still return IDs for this relationship.
//        if includeMessages {
            query = query.with(\.$messages)
//        }

        let primaryFuture = query.all()

        let resourcesFuture = primaryFuture
            .flatMapThrowing { descriptors -> [(APITestDescriptor, [BatchAPITestDescriptorDocument.Include])] in
                try descriptors
                    .map { try $0.serializable() }
                    .map {
                        (
                            $0.descriptor,
                            ($0.source.map(BatchAPITestDescriptorDocument.Include.init).map { [$0] } ?? [])
                            + $0.message.map(BatchAPITestDescriptorDocument.Include.init)
                        )
                }
        }

        let responseFuture = resourcesFuture.map { resources in
            BatchAPITestDescriptorDocument.SuccessDocument(apiDescription: .none,
                                                           body: .init(resourceObjects: resources.map { $0.0 }),
                                                           includes: .none,
                                                           meta: .none,
                                                           links: .none)
        }

        guard includeMessages || includeSource else {
            return responseFuture
        }

        let includesFuture = resourcesFuture.map { resources in
            Includes(
                values: resources
                    .flatMap { $0.1 }
            )
        }

        return resourcesFuture.and(includesFuture).map { (resources, includes) in
            BatchAPITestDescriptorDocument.SuccessDocument(apiDescription: .none,
                                                           body: .init(resourceObjects: resources.map { $0.0 }),
                                                           includes: includes,
                                                           meta: .none,
                                                           links: .none)
        }
    }

    /// Pass a query builder where the first result will be used.
    static func singleAPITestDescriptorResponse(query: QueryBuilder<DB.APITestDescriptor>, includeSource: Bool, includeMessages: Bool) -> EventLoopFuture<SingleAPITestDescriptorDocument.SuccessDocument> {

        var query = query

        if includeSource {
            query = query.with(\.$openAPISource)
        }
        // TODO: fix so that you can not include messages but still return IDs for this relationship.
//        if includeMessages {
            query = query.with(\.$messages)
//        }

        let primaryFuture = query.first()

        let resourceFuture = primaryFuture
            .flatMapThrowing { descriptor -> (APITestDescriptor, [SingleAPITestDescriptorDocument.Include])? in
                try descriptor
                    .map { try $0.serializable() }
                    .map {
                        (
                            $0.descriptor,
                            ($0.source.map(BatchAPITestDescriptorDocument.Include.init).map { [$0] } ?? [])
                                + $0.message.map(BatchAPITestDescriptorDocument.Include.init)
                        )
                }
        }.unwrap(or: Abort(.notFound))

        let responseFuture = resourceFuture
            .map { resource in
                SingleAPITestDescriptorDocument.SuccessDocument(apiDescription: .none,
                                                                body: .init(resourceObject: resource.0),
                                                                includes: .none,
                                                                meta: .none,
                                                                links: .none)
        }

        guard includeMessages || includeSource else {
            return responseFuture
        }

        let includesFuture = resourceFuture
            .map { resource in
                Includes(values: resource.1)
        }

        return responseFuture.and(includesFuture)
            .map { (response, includes) in
                response.including(includes)
        }
    }
}
