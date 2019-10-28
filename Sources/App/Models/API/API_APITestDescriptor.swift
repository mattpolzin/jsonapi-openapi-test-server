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
            public let status: Attribute<App.APITestDescriptor.Status>

            public init(createdAt: Date,
                        finishedAt: Date?,
                        status: App.APITestDescriptor.Status) {
                self.createdAt = .init(value: createdAt)
                self.finishedAt = .init(value: finishedAt)
                self.status = .init(value: status)
            }
        }

        public struct Relationships: JSONAPI.Relationships {
            public let messages: ToManyRelationship<APITestMessage, NoMetadata, NoLinks>

            public init(messages: [APITestMessage]) {
                self.messages = .init(resourceObjects: messages)
            }

            public init(messages: APITestMessage.Pointers) {
                self.messages = messages
            }

            public init(messageIds: [APITestMessage.Id]) {
                self.messages = .init(ids: messageIds)
            }
        }
    }

    public typealias APITestDescriptor = JSONAPI.ResourceObject<APITestDescriptorDescription, NoMetadata, NoLinks, UUID>

    public typealias SingleDocument<R: PrimaryResource, I: Include> = JSONAPI.Document<SingleResourceBody<R>, NoMetadata, NoLinks, I, NoAPIDescription, BasicJSONAPIError<String>>
    public typealias BatchDocument<R: PrimaryResource, I: Include> = JSONAPI.Document<ManyResourceBody<R>, NoMetadata, NoLinks, I, NoAPIDescription, BasicJSONAPIError<String>>

    public typealias BatchAPITestDescriptorResponse = BatchDocument<APITestDescriptor, Include1<APITestMessage>>

    public typealias SingleAPITestDescriptorResponse = SingleDocument<APITestDescriptor, Include1<APITestMessage>>

    static func batchAPITestDescriptorResponse(query: QueryBuilder<App.APITestDescriptor>, includeMessages: Bool) -> EventLoopFuture<BatchAPITestDescriptorResponse.SuccessDocument> {

        // ensure the messages are preloaded because that is necessary just to get relationship Ids.
        // Note this loses some efficiency for loading all related messages into swift objects instead
        // of just snagging the Ids as integers. That efficiency is not worth addressing until it is.
        let primaryFuture = query.with(\.$messages).all()

        let resourcesFuture: EventLoopFuture<[(APITestDescriptor, [APITestMessage])]> = primaryFuture
            .flatMapThrowing {
                try $0.map { apiTestDescriptor -> (APITestDescriptor, [APITestMessage]) in

                    return try apiTestDescriptor.serializable()
            }
        }

        let responseFuture = resourcesFuture.map { resources in
            BatchAPITestDescriptorResponse.SuccessDocument(apiDescription: .none,
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
            BatchAPITestDescriptorResponse.SuccessDocument(apiDescription: .none,
                                                           body: .init(resourceObjects: resources.map { $0.0 }),
                                                           includes: includes,
                                                           meta: .none,
                                                           links: .none)
        }
    }

    /// Pass a query builder where the first result will be used.
    static func singleAPITestDescriptorResponse(query: QueryBuilder<App.APITestDescriptor>, includeMessages: Bool) -> EventLoopFuture<SingleAPITestDescriptorResponse.SuccessDocument> {

        let primaryFuture = query.with(\.$messages).first()

        let resourceFuture = primaryFuture
            .flatMapThrowing {
                try $0?.serializable()
        }.unwrap(or: Abort(.notFound))

        let responseFuture = resourceFuture
            .map { resource in
                SingleAPITestDescriptorResponse.SuccessDocument(apiDescription: .none,
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
