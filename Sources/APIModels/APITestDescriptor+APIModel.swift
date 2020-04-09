//
//  JSONAPITestDescriptor.swift
//  App
//
//  Created by Mathew Polzin on 9/23/19.
//

import Foundation
import JSONAPI
import Poly

extension API {
    public enum APITestDescriptorDescription: JSONAPI.ResourceObjectDescription {
        public static let jsonType: String = "api_test_descriptor"

        public struct Attributes: JSONAPI.Attributes {
            public let createdAt: Attribute<Date>
            public let finishedAt: Attribute<Date?>
            public let status: Attribute<API.TestStatus>

            public init(createdAt: Date,
                        finishedAt: Date?,
                        status: API.TestStatus) {
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

    public enum NewAPITestDescriptorDescription: JSONAPI.ResourceObjectDescription {
        public static let jsonType: String = APITestDescriptorDescription.jsonType

        public typealias Attributes = NoAttributes

        public struct Relationships: JSONAPI.Relationships {
            public let openAPISource: ToOneRelationship<OpenAPISource, NoMetadata, NoLinks>?
        }
    }

    public typealias APITestDescriptor = JSONAPI.ResourceObject<APITestDescriptorDescription, NoMetadata, NoLinks, UUID>
    public typealias NewAPITestDescriptor = JSONAPI.ResourceObject<NewAPITestDescriptorDescription, NoMetadata, NoLinks, Unidentified>

    public typealias BatchAPITestDescriptorDocument = BatchDocument<APITestDescriptor, Include2<OpenAPISource, APITestMessage>>

    public typealias SingleAPITestDescriptorDocument = SingleDocument<APITestDescriptor, Include2<OpenAPISource, APITestMessage>>
    public typealias NewAPITestDescriptorDocument = SingleDocument<NewAPITestDescriptor, NoIncludes>
}

extension API {
    public enum TestStatus: String, Codable, CaseIterable {
        case pending
        case building
        case running
        case passed
        case failed
    }
}
