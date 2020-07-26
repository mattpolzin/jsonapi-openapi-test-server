//
//  APITestProperties+DB.swift
//  
//
//  Created by Mathew Polzin on 4/28/20.
//

import Vapor
import Foundation
import FluentKit
import APITesting
import OpenAPIReflection
import APIModels
import JSONAPI

extension DB {
    public final class APITestProperties: Model {
        public static let schema = "api_test_properties"

        @ID(key: "id")
        public var id: UUID?

        @Field(key: "created_at")
        public var createdAt: Date

        @Field(key: "api_host_override")
        public var apiHostOverride: URL?

        @Enum(key: "parser")
        public var parser: API.Parser

        @Parent(key: "openapi_source_id")
        public var openAPISource: OpenAPISource

        /// Create new test properties.
        public init(
            openAPISourceId: UUID,
            apiHostOverride: URL?,
            parser: API.Parser
        ) {
            self.id = UUID()
            self.createdAt = Date()
            self.$apiHostOverride.wrappedValue = apiHostOverride
            self.$parser.wrappedValue = parser
            self.$openAPISource.id = openAPISourceId
        }

        public init(apiModel: API.NewAPITestProperties, openAPISourceId: UUID) {
            self.id = UUID()
            self.createdAt = Date()
            self.$apiHostOverride.wrappedValue = apiModel.apiHostOverride
            self.$openAPISource.id = openAPISourceId
        }

        /// Used to construct Model from Database
        @available(*, deprecated, renamed: "init(id:)")
        public init() {}
    }
}

extension API.Parser: AnyJSONCaseIterable {}

extension DB.APITestProperties: JSONAPIConvertible {
    typealias JSONAPIModel = API.APITestProperties
    typealias JSONAPIIncludeType = API.SingleAPITestPropertiesDocument.IncludeType

    func jsonApiResources() throws -> CompoundResource<JSONAPIModel, JSONAPIIncludeType> {
        let sourceId = API.OpenAPISource.Id(rawValue: $openAPISource.id)
        let source = try $openAPISource.value?.jsonApiResources().primary

        let attributes = API.APITestProperties.Attributes(
            createdAt: createdAt,
            apiHostOverride: apiHostOverride,
            parser: parser
        )

        let relationships = API.APITestProperties.Relationships(
            openAPISourceId: sourceId
        )

        return .init(
            primary: API.APITestProperties(
                id: .init(rawValue: try requireID()),
                attributes: attributes,
                relationships: relationships,
                meta: .none,
                links: .none
            ),
            relatives: [source.map { .init($0) }].compactMap { $0 }
        )
    }
}
