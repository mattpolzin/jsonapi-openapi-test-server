//
//  OpenAPISource.swift
//  App
//
//  Created by Mathew Polzin on 12/9/19.
//

import Vapor
import Fluent
import APITesting

extension DB {
    public final class OpenAPISource: Model {
        public static let schema = "openapi_sources"

        @ID(key: "id")
        public var id: UUID?

        @Field(key: "created_at")
        var createdAt: Date

        @Field(key: "uri")
        var uri: String

        @Field(key: "source_type")
        var sourceType: SourceType

        public init(uri: String, sourceType: SourceType) {
            id = UUID()
            createdAt = Date()
            self.uri = uri
            self.sourceType = sourceType
        }

        init(apiModel: API.NewOpenAPISource) {
            self.id = UUID()
            self.createdAt = apiModel.createdAt
            self.uri = apiModel.uri
            self.sourceType = apiModel.sourceType
        }

        /// Used to construct Model from Database
        @available(*, deprecated, renamed: "init(uri:)")
        public init() {}
    }
}

extension DB.OpenAPISource {
    public enum SourceType: String, Codable, CaseIterable {
        case filepath = "filepath"
        case url = "url"
    }
}

extension OpenAPISource {
    public init(_ dbModel: DB.OpenAPISource) {
        switch dbModel.sourceType {
        case .filepath:
            self = .file(path: dbModel.uri)
        case .url:
            self = .unauthenticated(url: URI(string: dbModel.uri))
        }
    }

    public func dbModel(from database: FluentKit.Database) -> EventLoopFuture<DB.OpenAPISource> {
        let dbSourceType: DB.OpenAPISource.SourceType
        let uri: String

        switch self {
        case .file(path: let path):
            dbSourceType = .filepath
            uri = path
        case .unauthenticated(url: let url), .basicAuth(url: let url, _, _):
            dbSourceType = .url
            uri = url.string
        }

        return DB.OpenAPISource.query(on: database)
            .filter(\.$sourceType == dbSourceType)
            .filter(\.$uri == uri)
            .first(orCreate: DB.OpenAPISource(uri: uri, sourceType: dbSourceType))
    }
}

extension DB.OpenAPISource {
    func serializable() throws -> API.OpenAPISource {

        let attributes = API.OpenAPISource.Attributes(createdAt: createdAt,
                                                      uri: uri,
                                                      sourceType: sourceType)

        return API.OpenAPISource(id: .init(rawValue: try requireID()),
                                 attributes: attributes,
                                 relationships: .none,
                                 meta: .none,
                                 links: .none)
    }
}
