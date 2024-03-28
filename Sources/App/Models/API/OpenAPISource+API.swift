//
//  OpenAPISource+API.swift
//  
//
//  Created by Mathew Polzin on 4/8/20.
//

import Foundation
import APIModels
import Fluent
import Vapor
import JSONAPI

extension API {
    static func batchOpenAPISourceResponse(query: QueryBuilder<DB.OpenAPISource>) async throws -> BatchOpenAPISourceDocument.SuccessDocument {

        let sources = try await query.all()

        let resources = try sources.map { try $0.jsonApiResources() }

        return BatchOpenAPISourceDocument.SuccessDocument(resources: resources)
    }

    /// Pass a query builder where the first result will be used.
    static func singleOpenAPISourceResponse(query: QueryBuilder<DB.OpenAPISource>) async throws -> SingleOpenAPISourceDocument.SuccessDocument {

        let source = try await query.first()

        guard let resource = try source?.jsonApiResources() else { throw Abort(.notFound) }

        return SingleOpenAPISourceDocument.SuccessDocument(resource: resource)
    }
}
