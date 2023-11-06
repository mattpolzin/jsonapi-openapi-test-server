//
//  APITestProperties+APIModel.swift
//  
//
//  Created by Mathew Polzin on 4/28/20.
//

import Foundation
import JSONAPI
import Poly

extension API {
    public enum APITestPropertiesDescription: JSONAPI.ResourceObjectDescription {
        public static let jsonType: String = "api_test_properties"

        public struct Attributes: JSONAPI.SparsableAttributes {
            public let createdAt: Attribute<Date>
            public let apiHostOverride: Attribute<URL?>

            public init(
                createdAt: Date,
                apiHostOverride: URL?
            ) {
                self.createdAt = .init(value: createdAt)
                self.apiHostOverride = .init(value: apiHostOverride)
            }

            public enum CodingKeys: SparsableCodingKey {
                case createdAt
                case apiHostOverride
            }
        }

        public struct Relationships: JSONAPI.Relationships {
            public let openAPISource: ToOneRelationship<OpenAPISource, NoIdMetadata, NoMetadata, NoLinks>

            public init(openAPISource: OpenAPISource) {
                self.openAPISource = .init(resourceObject: openAPISource)
            }

            public init(openAPISource: OpenAPISource.Pointer) {
                self.openAPISource = openAPISource
            }

            public init(openAPISourceId: OpenAPISource.Id) {
                self.openAPISource = .init(id: openAPISourceId)
            }
        }
    }

    public enum NewAPITestPropertiesDescription: JSONAPI.ResourceObjectDescription {
        public static let jsonType: String = APITestProperties.jsonType

        public struct Attributes: JSONAPI.Attributes {
            public let apiHostOverride: Attribute<URL?>

            public init(apiHostOverride: URL?) {
                self.apiHostOverride = .init(value: apiHostOverride)
            }
        }

        public struct Relationships: JSONAPI.Relationships {
            public let openAPISource: ToOneRelationship<OpenAPISource, NoIdMetadata, NoMetadata, NoLinks>?

            public init(openAPISource: ToOneRelationship<OpenAPISource, NoIdMetadata, NoMetadata, NoLinks>? = nil) {
                self.openAPISource = openAPISource
            }
        }
    }

    public typealias APITestProperties = JSONAPI.ResourceObject<APITestPropertiesDescription, NoMetadata, NoLinks, UUID>
    public typealias NewAPITestProperties = JSONAPI.ResourceObject<NewAPITestPropertiesDescription, NoMetadata, NoLinks, Unidentified>

    public typealias BatchAPITestPropertiesDocument = BatchDocument<APITestProperties, Include1<OpenAPISource>>

    public typealias SingleAPITestPropertiesDocument = SingleDocument<APITestProperties, Include1<OpenAPISource>>

    public typealias CreateAPITestPropertiesDocument = SingleDocument<NewAPITestProperties, NoIncludes>.SuccessDocument
}
