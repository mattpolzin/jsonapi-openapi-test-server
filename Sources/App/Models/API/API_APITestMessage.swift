//
//  API_APITestMessage.swift
//  App
//
//  Created by Mathew Polzin on 9/23/19.
//

import Foundation
import JSONAPI

extension API {
    struct APITestMessageDescription: JSONAPI.ResourceObjectDescription {
        public static let jsonType: String = "api_test_message"

        public struct Attributes: JSONAPI.Attributes {
            public let createdAt: Attribute<Date>
            public let messageType: Attribute<App.APITestMessage.MessageType>
            public let path: Attribute<String?>
            public let context: Attribute<String?>
            public let message: Attribute<String>
        }

        public struct Relationships: JSONAPI.Relationships {
            public let apiTestDescriptor: ToOneRelationship<APITestDescriptor, NoMetadata, NoLinks>
        }
    }

    typealias APITestMessage = JSONAPI.ResourceObject<APITestMessageDescription, NoMetadata, NoLinks, UUID>
}
