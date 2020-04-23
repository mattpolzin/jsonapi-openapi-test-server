//
//  File.swift
//  
//
//  Created by Mathew Polzin on 4/22/20.
//

import Vapor
import VaporTypedRoutes
import FluentKit
import SwiftGen
import APITesting
import JSONAPI
import struct Logging.Logger
import APIModels

/// Controls basic CRUD operations on API Test Messages.
final class APITestMessageController: Controller {
    static func show(_ req: TypedRequest<ShowContext>) throws -> EventLoopFuture<Response> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            return req.response.badRequest
        }

        return showResults(
            id: id,
            db: req.db
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

    static func showResults(id: UUID, db: Database) -> EventLoopFuture<API.SingleAPITestMessageDocument.SuccessDocument> {
        let query = DB.APITestMessage.query(on: db)
            .filter(\.$id == id)

        return API.singleAPITestMessageResponse(
            query: query
        )
    }
}

// MARK: - Route Contexts
extension APITestMessageController {

    struct ShowContext: RouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let success: ResponseContext<API.SingleAPITestMessageDocument.SuccessDocument> =
            .init { response in
                response.status = .ok
        }

        let notFound: CannedResponse<API.SingleAPITestMessageDocument.ErrorDocument>
            = Controller.jsonNotFoundError(details: "The requested tests were not found")

        let badRequest: CannedResponse<API.SingleAPITestMessageDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "Test ID not specified in path")

        let serverError: CannedResponse<API.SingleAPITestMessageDocument.ErrorDocument>
            = Controller.jsonServerError()

        static let shared = Self()
    }
}
