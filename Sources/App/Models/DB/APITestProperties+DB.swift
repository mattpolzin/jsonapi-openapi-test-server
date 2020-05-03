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

extension DB {
    public final class APITestProperties: Model {
        public static let schema = "api_test_properties"

        @ID(key: "id")
        public var id: UUID?

        @Field(key: "created_at")
        public var createdAt: Date

        @Field(key: "api_host_override")
        public var apiHostOverride: URL?

        @Parent(key: "openapi_source_id")
        public var openAPISource: OpenAPISource

        /// Create new test properties.
        public init(openAPISourceId: UUID, apiHostOverride: URL?) {
            self.id = UUID()
            self.createdAt = Date()
            self.$apiHostOverride.wrappedValue = apiHostOverride
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

extension DB.APITestProperties {
    func serializable() throws -> (properties: API.APITestProperties, source: API.OpenAPISource?) {

        let sourceId = API.OpenAPISource.Id(rawValue: $openAPISource.id)
        let source = try $openAPISource.value?.serializable()

        let attributes = API.APITestProperties.Attributes(
            createdAt: createdAt,
            apiHostOverride: apiHostOverride
        )

        let relationships = API.APITestProperties.Relationships(
            openAPISourceId: sourceId
        )

        return (
            API.APITestProperties(
                id: .init(rawValue: try requireID()),
                attributes: attributes,
                relationships: relationships,
                meta: .none,
                links: .none
            ),
            source
        )
    }
}

