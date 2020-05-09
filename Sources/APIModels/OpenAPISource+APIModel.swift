//
//  API_OpenAPISource.swift
//  App
//
//  Created by Mathew Polzin on 9/23/19.
//

import Foundation
import JSONAPI
import Poly

extension API {
    public enum OpenAPISourceDescription: JSONAPI.ResourceObjectDescription {
        public static let jsonType: String = "openapi_source"

        public struct Attributes: JSONAPI.SparsableAttributes {
            public let createdAt: Attribute<Date>
            public let uri: Attribute<String>
            public let sourceType: Attribute<API.SourceType>

            public init(createdAt: Date,
                        uri: String,
                        sourceType: API.SourceType) {
                self.createdAt = .init(value: createdAt)
                self.uri = .init(value: uri)
                self.sourceType = .init(value: sourceType)
            }

            public enum CodingKeys: SparsableCodingKey {
                case createdAt
                case uri
                case sourceType
            }
        }

        public typealias Relationships = NoRelationships
    }

    public typealias OpenAPISource = JSONAPI.ResourceObject<OpenAPISourceDescription, NoMetadata, NoLinks, UUID>
    public typealias NewOpenAPISource = JSONAPI.ResourceObject<OpenAPISourceDescription, NoMetadata, NoLinks, Unidentified>

    public typealias BatchOpenAPISourceDocument = BatchDocument<OpenAPISource, NoIncludes>

    public typealias SingleOpenAPISourceDocument = SingleDocument<OpenAPISource, NoIncludes>

    public typealias CreateOpenAPISourceDocument = SingleDocument<NewOpenAPISource, NoIncludes>.SuccessDocument
}

extension API {
    public enum SourceType: String, Codable, CaseIterable {
        case filepath = "filepath"
        case url = "url"
    }
}
