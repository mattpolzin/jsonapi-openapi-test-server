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

extension API {
    struct APITestDescriptorDescription: JSONAPI.ResourceObjectDescription {
        public static let jsonType: String = "api_test_descriptor"

        public struct Attributes: JSONAPI.Attributes {
            public let createdAt: Attribute<Date>
            public let finishedAt: Attribute<Date?>
            public let status: Attribute<App.APITestDescriptor.Status>
        }

        public struct Relationships: JSONAPI.Relationships {
            public let messages: ToManyRelationship<APITestMessage, NoMetadata, NoLinks>
        }
    }

    typealias APITestDescriptor = JSONAPI.ResourceObject<APITestDescriptorDescription, NoMetadata, NoLinks, UUID>

    typealias SingleDocument<R: PrimaryResource, I: Include> = JSONAPI.Document<SingleResourceBody<R>, NoMetadata, NoLinks, I, NoAPIDescription, UnknownJSONAPIError>
    typealias BatchDocument<R: PrimaryResource, I: Include> = JSONAPI.Document<ManyResourceBody<R>, NoMetadata, NoLinks, I, NoAPIDescription, UnknownJSONAPIError>

    typealias BatchAPITestDescriptorResponse = Either<
        BatchDocument<APITestDescriptor, Include1<APITestMessage>>,
        BatchDocument<APITestDescriptor, NoIncludes>
    >

    typealias SingleAPITestDescriptorResponse = Either<
        SingleDocument<APITestDescriptor, Include1<APITestMessage>>,
        SingleDocument<APITestDescriptor, NoIncludes>
    >

    static func batchAPITestDescriptorResponse(query: QueryBuilder<App.APITestDescriptor>, includeMessages: Bool) -> EventLoopFuture<BatchAPITestDescriptorResponse> {

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
            BatchDocument<APITestDescriptor, NoIncludes>(apiDescription: .none,
                                                         body: .init(resourceObjects: resources.map { $0.0 }),
                                                         includes: .none,
                                                         meta: .none,
                                                         links: .none)
        }

        guard includeMessages else {
            return responseFuture.map(BatchAPITestDescriptorResponse.init)
        }

        let includesFuture = resourcesFuture.map { resources in
            Includes(values: resources.flatMap { $0.1 }.map { Include1($0) })
        }

        return responseFuture.and(includesFuture).map { (response, includes) in
            BatchAPITestDescriptorResponse(response.including(includes))
        }
    }

//    static func singleAPITestDescriptorResponse(query: QueryBuilder<App.APITestDescriptor>, includeMessages: Bool) -> EventLoopFuture<SingleAPITestDescriptorResponse> {
//
//        // ensure the messages are preloaded because that is necessary just to get relationship Ids.
//        // Note this loses some efficiency for loading all related messages into swift objects instead
//        // of just snagging the Ids as integers. That efficiency is not worth addressing until it is.
//        let primaryFuture = query.with(\.$messages).all()
//
//        
//
//        return .init(apiDescription: .none,
//                     body: .init(resourceObject: primary),
//                     includes: .none,
//                     meta: .none,
//                     links: .none)
//    }
}
