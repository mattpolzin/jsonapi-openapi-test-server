//
//  APITestMessageController.swift
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
public final class APITestMessageController: Controller {
    static func show(_ req: TypedRequest<ShowContext>) throws -> EventLoopFuture<Response> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            return req.response.badRequest
        }

        let shouldIncludeDescriptor = req.query.include?
            .contains("apiTestDescriptor")
            ?? false

        return showResults(
            id: id,
            shouldIncludeTestDescriptor: shouldIncludeDescriptor,
            db: req.db
        )
            .flatMap(req.response.success.encode)
    }

    static func showResults(id: UUID, shouldIncludeTestDescriptor: Bool, db: Database) -> EventLoopFuture<API.SingleAPITestMessageDocument.SuccessDocument> {
        let query = DB.APITestMessage.query(on: db)
            .filter(\.$id == id)

        return API.singleAPITestMessageResponse(
            query: query,
            includeTestDescriptor: shouldIncludeTestDescriptor
        )
    }
}

// MARK: - Route Contexts
extension APITestMessageController {

    struct ShowContext: JSONAPIRouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let include: CSVQueryParam<String> = .init(
            name: "include",
            description: "Include the given types of resources in the response.",
            allowedValues: ["apiTestDescriptor"]
        )

        let success: ResponseContext<API.SingleAPITestMessageDocument.SuccessDocument> = .init { response in
            response.status = .ok
            response.headers.contentType = .jsonAPI
        }

        let notFound: CannedResponse<API.SingleAPITestMessageDocument.ErrorDocument>
            = Controller.jsonNotFoundError(details: "The requested message was not found")

        let badRequest: CannedResponse<API.SingleAPITestMessageDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "Message ID not specified in path")

        static let shared = Self()
    }
}

// MARK: - Route Configuration
extension APITestMessageController {
    public static func mount(on app: Application, at rootPath: RoutingKit.PathComponent...) {
        app.on(
            .GET,
            rootPath.map(\.openAPIPathComponent) + [":id".description("Id of the API Test Message.")],
            use: Self.show
        )
    }
}
