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
final class OpenAPISourceController: Controller {

    override init() {}

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
            .flatMapError { _ in req.response.serverError }
    }

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
            .flatMapError { error in
                guard let abortError = error as? Abort,
                    abortError.status == .notFound else {
                        return req.response.serverError
                }
                return req.response.notFound
        }
    }

    /// Create an `OpenAPISource`.
    func create(_ req: TypedRequest<CreateContext>) throws -> EventLoopFuture<Response> {

        let source = req.eventLoop.makeSucceededFuture(())
            .flatMapThrowing { try req.decodeBody().body.primaryResource?.value }
            .unwrap(or: Abort(.badRequest))

        let sourceModel = source
            .map(DB.OpenAPISource.init(apiModel:))

        return sourceModel
            .flatMap { $0.save(on: req.db) }
            .flatMap { sourceModel }
            .flatMapThrowing { responseModel in
                API.SingleOpenAPISourceDocument.SuccessDocument(
                    apiDescription: .none,
                    body: .init(resourceObject: try responseModel.serializable()),
                    includes: .none,
                    meta: .none,
                    links: .none
                )
            }
            .flatMap(req.response.success.encode)
            .flatMapError { error in
                guard let abortError = error as? Abort,
                    abortError.status == .badRequest else {
                        return req.response.serverError
                }
                return req.response.badRequest
        }
    }
}

// MARK: - Route Contexts
extension OpenAPISourceController {
    struct IndexContext: RouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let success: ResponseContext<API.BatchOpenAPISourceDocument.SuccessDocument> =
            .init { response in
                response.status = .ok
        }

        let serverError: CannedResponse<API.BatchOpenAPISourceDocument.ErrorDocument>
            = Controller.jsonServerError()

        static let shared = Self()
    }

    struct ShowContext: RouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let success: ResponseContext<API.SingleOpenAPISourceDocument.SuccessDocument> =
            .init { response in
                response.status = .ok
        }

        let notFound: CannedResponse<API.SingleOpenAPISourceDocument.ErrorDocument>
            = Controller.jsonNotFoundError(details: "The requested OpenAPI Source was not found")

        let badRequest: CannedResponse<API.SingleOpenAPISourceDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "OpenAPISource ID not specified in path")

        let serverError: CannedResponse<API.SingleOpenAPISourceDocument.ErrorDocument>
            = Controller.jsonServerError()

        static let shared = Self()
    }

    struct CreateContext: RouteContext {
        typealias RequestBodyType = API.CreateOpenAPISourceDocument.SuccessDocument

        let success: ResponseContext<API.SingleOpenAPISourceDocument.SuccessDocument> =
            .init { response in
                response.status = .created
        }

        let badRequest: CannedResponse<API.SingleOpenAPISourceDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "Request body could not be parsed as an 'openapi_source' resource")

        let serverError: CannedResponse<API.SingleOpenAPISourceDocument.ErrorDocument>
            = Controller.jsonServerError()

        static let shared = Self()
    }
}

// MARK: - Route Configuration
extension OpenAPISourceController {
    public func mount(on app: Application, at rootPath: RoutingKit.PathComponent...) {
        app.on(.POST, rootPath, use: self.create)
            .tags("Sources")
            .summary("Create a new OpenAPI Source")

        app.on(.GET, rootPath, use: self.index)
            .tags("Sources")
            .summary("Retrieve all OpenAPI Sources")

        app.on(.GET, rootPath + [":id"], use: self.show)
            .tags("Sources")
            .summary("Retrieve a single OpenAPI Source")
    }
}
