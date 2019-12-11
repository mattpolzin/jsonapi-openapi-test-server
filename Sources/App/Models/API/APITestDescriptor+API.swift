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

    public typealias BatchAPITestDescriptorDocument = BatchDocument<APITestDescriptor, Include1<APITestMessage>>

    public typealias SingleAPITestDescriptorDocument = SingleDocument<APITestDescriptor, Include1<APITestMessage>>

    static func batchAPITestDescriptorResponse(query: QueryBuilder<DB.APITestDescriptor>, includeMessages: Bool) -> EventLoopFuture<BatchAPITestDescriptorDocument.SuccessDocument> {

        // ensure the messages are preloaded because that is necessary just to get relationship Ids.
        // Note this loses some efficiency for loading all related messages into swift objects instead
        // of just snagging the Ids as integers. That efficiency is not worth addressing until it is.
        let primaryFuture = query.with(\.$messages).with(\.$openAPISource).all()

        let resourcesFuture: EventLoopFuture<[(APITestDescriptor, [APITestMessage])]> = primaryFuture
            .flatMapThrowing {
                try $0.map { apiTestDescriptor -> (APITestDescriptor, [APITestMessage]) in
                    try apiTestDescriptor.serializable()
            }
        }

        let responseFuture = resourcesFuture.map { resources in
            BatchAPITestDescriptorDocument.SuccessDocument(apiDescription: .none,
                                                           body: .init(resourceObjects: resources.map { $0.0 }),
                                                           includes: .none,
                                                           meta: .none,
                                                           links: .none)
        }

        guard includeMessages else {
            return responseFuture
        }

        let includesFuture = resourcesFuture.map { resources in
            Includes(values: resources.flatMap { $0.1 }.map { Include1($0) })
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
    static func singleAPITestDescriptorResponse(query: QueryBuilder<DB.APITestDescriptor>, includeMessages: Bool) -> EventLoopFuture<SingleAPITestDescriptorDocument.SuccessDocument> {

        // ensure the messages are preloaded because that is necessary just to get relationship Ids.
        // Note this loses some efficiency for loading all related messages into swift objects instead
        // of just snagging the Ids as integers. That efficiency is not worth addressing until it is.
        let primaryFuture = query.with(\.$messages).with(\.$openAPISource).first()

        let resourceFuture = primaryFuture
            .flatMapThrowing {
                try $0?.serializable()
        }.unwrap(or: Abort(.notFound))

        let responseFuture = resourceFuture
            .map { resource in
                SingleAPITestDescriptorDocument.SuccessDocument(apiDescription: .none,
                                                                body: .init(resourceObject: resource.0),
                                                                includes: .none,
                                                                meta: .none,
                                                                links: .none)
        }

        guard includeMessages else {
            return responseFuture
        }

        let includesFuture = resourceFuture
            .map { resource in
                Includes(values: resource.1.map { Include1($0) })
        }

        return responseFuture.and(includesFuture)
            .map { (response, includes) in
                response.including(includes)
        }
    }
}
