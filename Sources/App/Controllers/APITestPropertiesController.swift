//
//  APITestPropertiesController.swift
//  
//
//  Created by Mathew Polzin on 4/29/20.
//

import Vapor
import VaporTypedRoutes
import FluentKit
import SwiftGen
import APITesting
import struct Logging.Logger
import APIModels
import JSONAPI

/// Controls basic CRUD operations on OpenAPI Sources.
public final class APITestPropertiesController: Controller {

    let defaultOpenAPISource: OpenAPISource?

    public init(openAPISource: OpenAPISource?) {
        self.defaultOpenAPISource = openAPISource
    }

    deinit {}
}

// MARK: - Routes
extension APITestPropertiesController {
    /// Returns a list of all `APITestProperties`.
    func index(_ req: TypedRequest<IndexContext>) throws -> EventLoopFuture<Response> {

        let shouldIncludeSource = req.query.include?
            .contains("openAPISource")
            ?? false

        return API.batchAPITestPropertiesResponse(
            query: DB.APITestProperties.query(on: req.db),
            includeSource: shouldIncludeSource
        )
            .flatMap(req.response.success.encode)
    }

    func show(_ req: TypedRequest<ShowContext>) throws -> EventLoopFuture<Response> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            return req.response.badRequest
        }

        let shouldIncludeSource = req.query.include?
            .contains("openAPISource")
            ?? false

        let query = DB.APITestProperties.query(on: req.db)
            .filter(\.$id == id)

        return API.singleAPITestPropertiesResponse(
            query: query,
            includeSource: shouldIncludeSource
        )
            .flatMap(req.response.success.encode)
    }

    /// Create an `OpenAPISource`.
    func create(_ req: TypedRequest<CreateContext>) throws -> EventLoopFuture<Response> {

        let properties = req.eventLoop.makeSucceededFuture(())
            .flatMapThrowing { try req.decodeBody().primaryResource.value }

        let givenOpenAPISourceId = properties
            .map { ($0 ~> \.openAPISource)?.rawValue }
            .optionalFlatMap {
                DB.OpenAPISource.find($0, on: req.db)
                    .unwrap(or: Abort(.badRequest, reason: "The specified OpenAPI source could not be found."))
        }

        let openAPISourceId: EventLoopFuture<UUID> = givenOpenAPISourceId
            .flatMap { (source: DB.OpenAPISource?) in
                if let id = source?.id {
                    return req.eventLoop.makeSucceededFuture(id)
                }

                return self.defaultSource(on: req.db)
                    .map { $0.id }
                    .unwrap(or: Abort(.badRequest, reason: "There was no OpenAPI source specified and no default was found."))
        }

        let requestedPropertiesModel = properties.and(openAPISourceId)
            .map { DB.APITestProperties.init(apiModel: $0.0, openAPISourceId: $0.1) }

        let propertiesModel = requestedPropertiesModel.flatMap { properties in
            DB.APITestProperties.query(on: req.db)
                .filter(\.$openAPISource.$id == properties.$openAPISource.id)
                .filter(\.$apiHostOverride == properties.apiHostOverride)
                .filter(\.$parser == properties.parser)
                .first(orCreate: properties)
        }

        return propertiesModel
            .flatMapThrowing { responseModel in
                API.SingleAPITestPropertiesDocument.SuccessDocument(
                    apiDescription: .none,
                    body: .init(resourceObject: try responseModel.jsonApiResources().primary),
                    includes: .none,
                    meta: .none,
                    links: .none
                )
        }
        .flatMap(req.response.success.encode)
    }
}

extension APITestPropertiesController {
    func defaultSource(on db: Database) -> EventLoopFuture<DB.OpenAPISource> {
        guard let defaultSource = defaultOpenAPISource else {
            return db.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "No Open API Source specified and no default OpenAPI Source available."))
        }

        return defaultSource
            .dbModel(from: db)
    }
}

// MARK: - Route Contexts
extension APITestPropertiesController {
    struct IndexContext: JSONAPIRouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let include: CSVQueryParam<String> = .init(
            name: "include",
            description: "Include the given types of resources in the response.",
            allowedValues: ["openAPISource"]
        )

        let success: ResponseContext<API.BatchAPITestPropertiesDocument.SuccessDocument> = .init { response in
            response.status = .ok
            response.headers.contentType = .jsonAPI
        }

        static let shared = Self()
    }

    struct ShowContext: JSONAPIRouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let include: CSVQueryParam<String> = .init(
            name: "include",
            description: "Include the given types of resources in the response.",
            allowedValues: ["openAPISource"]
        )

        let success: ResponseContext<API.SingleAPITestPropertiesDocument.SuccessDocument> = .init { response in
            response.status = .ok
            response.headers.contentType = .jsonAPI
        }

        let notFound: CannedResponse<API.SingleAPITestPropertiesDocument.ErrorDocument>
            = Controller.jsonNotFoundError(details: "The requested API Test Properties object was not found")

        let badRequest: CannedResponse<API.SingleAPITestPropertiesDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "API Test Properties ID not specified in path")

        static let shared = Self()
    }

    struct CreateContext: JSONAPIRouteContext {
        typealias RequestBodyType = API.CreateAPITestPropertiesDocument

        let success: ResponseContext<API.SingleAPITestPropertiesDocument.SuccessDocument> = .init { response in
            response.status = .created
            response.headers.contentType = .jsonAPI
        }

        let badRequest: CannedResponse<API.SingleAPITestPropertiesDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "Request body could not be parsed as an 'openapi_source' resource")

        static let shared = Self()
    }
}

// MARK: - Route Configuration
extension APITestPropertiesController {
    public func mount(on app: Application, at rootPath: RoutingKit.PathComponent...) {
        app.on(
            .POST,
            rootPath.map(\.openAPIPathComponent),
            use: self.create
        )
            .tags("Test Properties")
            .summary("Create a new API Test Properties resource")

        app.on(
            .GET,
            rootPath.map(\.openAPIPathComponent),
            use: self.index
        )
            .tags("Test Properties")
            .summary("Retrieve all API Test Properties resources")

        app.on(
            .GET,
            rootPath.map(\.openAPIPathComponent) + [":id".description("Id of the API Test Properties.")],
            use: self.show
        )
            .tags("Test Properties")
            .summary("Retrieve a single Test Properties resource")
    }
}
