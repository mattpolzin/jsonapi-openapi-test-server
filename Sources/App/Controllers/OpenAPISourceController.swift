//
//  OpenAPISourceController.swift
//  App
//
//  Created by Mathew Polzin on 12/10/19.
//

import Vapor
import VaporTypedRoutes
import FluentKit
import SwiftGen
import APITesting
import struct Logging.Logger
import APIModels

/// Controls basic CRUD operations on OpenAPI Sources.
public final class OpenAPISourceController: Controller {

    public override init() {}

    deinit {}
}

// MARK: - Routes
extension OpenAPISourceController {
    /// Returns a list of all `OpenAPISource`s.
    func index(_ req: TypedRequest<IndexContext>) throws -> EventLoopFuture<Response> {

        return API.batchOpenAPISourceResponse(
            query: DB.OpenAPISource.query(on: req.db)
        )
            .flatMap(req.response.success.encode)
    }

    /// Show an `OpenAPISource`.
    func show(_ req: TypedRequest<ShowContext>) throws -> EventLoopFuture<Response> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            return req.response.badRequest
        }

        let query = DB.OpenAPISource.query(on: req.db)
            .filter(\.$id == id)

        return API.singleOpenAPISourceResponse(
            query: query
        )
            .flatMap(req.response.success.encode)
    }

    /// Create an `OpenAPISource`.
    func create(_ req: TypedRequest<CreateContext>) throws -> EventLoopFuture<Response> {

        let source = req.eventLoop.makeSucceededFuture(())
            .flatMapThrowing { try req.decodeBody().primaryResource.value }

        let requestedSourceModel = source
            .map(DB.OpenAPISource.init(apiModel:))

        let sourceModel = requestedSourceModel.flatMap { model in
            DB.OpenAPISource.query(on: req.db)
                .filter(\.$sourceType == model.sourceType)
                .filter(\.$uri == model.uri)
                .first(orCreate: model)
        }

        return sourceModel
            .flatMapThrowing { responseModel in
                API.SingleOpenAPISourceDocument.SuccessDocument(
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

// MARK: - Route Contexts
extension OpenAPISourceController {
    struct IndexContext: JSONAPIRouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let success: ResponseContext<API.BatchOpenAPISourceDocument.SuccessDocument> = .init { response in
            response.status = .ok
            response.headers.contentType = .jsonAPI
        }

        static let shared = Self()
    }

    struct ShowContext: JSONAPIRouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let success: ResponseContext<API.SingleOpenAPISourceDocument.SuccessDocument> = .init { response in
            response.status = .ok
            response.headers.contentType = .jsonAPI
        }

        let notFound: CannedResponse<API.SingleOpenAPISourceDocument.ErrorDocument>
            = Controller.jsonNotFoundError(details: "The requested OpenAPI Source was not found")

        let badRequest: CannedResponse<API.SingleOpenAPISourceDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "OpenAPISource ID not specified in path")

        static let shared = Self()
    }

    struct CreateContext: JSONAPIRouteContext {
        typealias RequestBodyType = API.CreateOpenAPISourceDocument

        let success: ResponseContext<API.SingleOpenAPISourceDocument.SuccessDocument> = .init { response in
            response.status = .created
            response.headers.contentType = .jsonAPI
        }

        let badRequest: CannedResponse<API.SingleOpenAPISourceDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "Request body could not be parsed as an 'openapi_source' resource")

        static let shared = Self()
    }
}

// MARK: - Route Configuration
extension OpenAPISourceController {
    public func mount(on app: Application, at rootPath: RoutingKit.PathComponent...) {
        app.on(
            .POST,
            rootPath.map(\.openAPIPathComponent),
            use: self.create
        )
            .tags("Sources")
            .summary("Create a new OpenAPI Source")

        app.on(
            .GET,
            rootPath.map(\.openAPIPathComponent),
            use: self.index
        )
            .tags("Sources")
            .summary("Retrieve all OpenAPI Sources")

        app.on(
            .GET,
            rootPath.map(\.openAPIPathComponent) + [":id".description("Id of OpenAPI Source.")],
            use: self.show)
            .tags("Sources")
            .summary("Retrieve a single OpenAPI Source")
    }
}
