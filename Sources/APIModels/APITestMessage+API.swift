//
//  API_APITestMessage.swift
//  App
//
//  Created by Mathew Polzin on 9/23/19.
//

import Foundation
import JSONAPI

extension API {
    public enum APITestMessageDescription: JSONAPI.ResourceObjectDescription {
        public static let jsonType: String = "api_test_message"

        public struct Attributes: JSONAPI.Attributes {
            public let createdAt: Attribute<Date>
            public let messageType: Attribute<API.MessageType>
            public let path: Attribute<String?>
            public let context: Attribute<String?>
            public let message: Attribute<String>

            public init(createdAt: Date,
                        messageType: API.MessageType,
                        path: String?,
                        context: String?,
                        message: String) {
                self.createdAt = .init(value: createdAt)
                self.messageType = .init(value: messageType)
                self.path = .init(value: path)
                self.context = .init(value: context)
                self.message = .init(value: message)
            }
        }

        public struct Relationships: JSONAPI.Relationships {
            public let apiTestDescriptor: ToOneRelationship<APITestDescriptor, NoMetadata, NoLinks>

            public init(apiTestDescriptor: APITestDescriptor.Pointer) {
                self.apiTestDescriptor = apiTestDescriptor
            }

            public init(apiTestDescriptorId: APITestDescriptor.Id) {
                self.apiTestDescriptor = .init(id: apiTestDescriptorId)
            }
        }
    }

    public typealias APITestMessage = JSONAPI.ResourceObject<APITestMessageDescription, NoMetadata, NoLinks, UUID>
}

extension API {
    public enum MessageType: String, Codable, CaseIterable {
        case debug = "debug"
        case info = "info"
        case warning = "warning"
        case success = "success"
        case error = "error"
    }
}
