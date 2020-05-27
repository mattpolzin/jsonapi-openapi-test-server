
//
//  JSONAPIErrorMiddleware.swift
//  
//
//  Created by Mathew Polzin on 5/6/20.
//

import Vapor
import JSONAPI

public final class JSONAPIErrorMiddleware: Vapor.Middleware {
    public init() {}

    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        next.respond(to: request).flatMapError { self.response(for: $0, given: request) }
    }

    func response(for error: Error, given request: Request) -> EventLoopFuture<Response> {

        request.logger.report(error: error)

        if error is DecodingError {
            return request.eventLoop.makeSucceededFuture(
                Self.unprocessableEntityError(details: error.localizedDescription)
            )
        }

        if error is JSONAPI.DocumentDecodingError {
            return request.eventLoop.makeSucceededFuture(
                Self.unprocessableEntityError(details: String(describing: error))
            )
        }

        guard let abortError = error as? Abort else {
            if let continueError = error as? AsyncKit.EventLoopFutureQueue.ContinueError {
                return request.eventLoop.makeSucceededFuture(
                    Self.serverError(details: String(describing: continueError))
                )
            }

            return request.eventLoop.makeSucceededFuture(
                Self.serverError(details: error.localizedDescription)
            )
        }

        let response: Response = {
            switch abortError.status {
            case .notFound:
                return Self.notFoundError(details: abortError.reason)
            case .badRequest:
                return Self.badRequestError(details: abortError.reason)
            default:
                return Self.serverError(details: abortError.reason)
            }
        }()

        return request.eventLoop.makeSucceededFuture(response)
    }

    static func unprocessableEntityError(details: String) -> Response {
        let error = BasicJSONAPIErrorPayload<String>(
            id: nil,
            title: HTTPResponseStatus.unprocessableEntity.reasonPhrase,
            detail: details
        )

        return encodedSingleError(payload: error, status: .unprocessableEntity)
    }

    static func badRequestError(details: String) -> Response {
        let error = JSONAPI.BasicJSONAPIErrorPayload<String>(
            id: nil,
            title: HTTPResponseStatus.badRequest.reasonPhrase,
            detail: details
        )

        return encodedSingleError(payload: error, status: .badRequest)
    }

    static func notFoundError(details: String) -> Response {
        let error = JSONAPI.BasicJSONAPIErrorPayload<String>(
            id: nil,
            title: HTTPResponseStatus.notFound.reasonPhrase,
            detail: details
        )

        return encodedSingleError(payload: error, status: .notFound)
    }

    static func serverError(details: String) -> Response {
        let error = JSONAPI.BasicJSONAPIErrorPayload<String>(
            id: nil,
            title: HTTPResponseStatus.internalServerError.reasonPhrase,
            detail: details
        )

        return encodedSingleError(payload: error, status: .internalServerError)
    }

    static func encodedSingleError(payload error: JSONAPI.BasicJSONAPIErrorPayload<String>, status: HTTPResponseStatus) -> Response {
        let errorDocument = JSONAPIErrorDocument(
            apiDescription: .none,
            errors: [ .error(error) ]
        )

        var headers = HTTPHeaders()
        headers.contentType = .jsonAPI

        return Response(
            status: status,
            headers: headers,
            body: .init(data: try! JSONEncoder().encode(errorDocument))
        )
    }
}

extension JSONAPIErrorMiddleware {
    typealias JSONAPIErrorDocument = JSONAPI.Document<NoResourceBody, NoMetadata, NoLinks, NoIncludes, NoAPIDescription, BasicJSONAPIError<String>>.ErrorDocument
}
