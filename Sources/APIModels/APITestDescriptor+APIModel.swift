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
            public let messages: ToManyRelationship<APITestMessage, NoIdMetadata, NoMetadata, NoLinks>
            public let testProperties: ToOneRelationship<APITestProperties, NoIdMetadata, NoMetadata, NoLinks>

            public init(testProperties: APITestProperties, messages: [APITestMessage]) {
                self.testProperties = .init(resourceObject: testProperties)
                self.messages = .init(resourceObjects: messages)
            }

            public init(testProperties: APITestProperties.Pointer, messages: APITestMessage.Pointers) {
                self.testProperties = testProperties
                self.messages = messages
            }

            public init(testPropertiesId: APITestProperties.Id, messageIds: [APITestMessage.Id]) {
                self.testProperties = .init(id: testPropertiesId)
                self.messages = .init(ids: messageIds)
            }
        }
    }

    public enum NewAPITestDescriptorDescription: JSONAPI.ResourceObjectDescription {
        public static let jsonType: String = APITestDescriptorDescription.jsonType

        public typealias Attributes = NoAttributes

        public struct Relationships: JSONAPI.Relationships {
            public let testProperties: ToOneRelationship<APITestProperties, NoIdMetadata, NoMetadata, NoLinks>?

            public init(testProperties: ToOneRelationship<APITestProperties, NoIdMetadata, NoMetadata, NoLinks>? = nil) {
                self.testProperties = testProperties
            }
        }
    }

    public typealias APITestDescriptor = JSONAPI.ResourceObject<APITestDescriptorDescription, NoMetadata, NoLinks, UUID>
    public typealias NewAPITestDescriptor = JSONAPI.ResourceObject<NewAPITestDescriptorDescription, NoMetadata, NoLinks, Unidentified>

    public typealias BatchAPITestDescriptorDocument = BatchDocument<APITestDescriptor, Include3<APITestProperties, OpenAPISource, APITestMessage>>

    public typealias SingleAPITestDescriptorDocument = SingleDocument<APITestDescriptor, Include3<APITestProperties, OpenAPISource, APITestMessage>>
    public typealias CreateAPITestDescriptorDocument = SingleDocument<NewAPITestDescriptor, NoIncludes>.SuccessDocument
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
