//
//  ControllerProtocol.swift
//  App
//
//  Created by Mathew Polzin on 12/8/19.
//

import Vapor
import VaporTypedRoutes
import FluentKit
import SwiftGen
import APIModels

public class Controller {}

// MARK: - Canned Responses
extension Controller {
    static func jsonServerError<ResponseBodyType: ResponseEncodable>() -> CannedResponse<ResponseBodyType> {
        var headers = HTTPHeaders()
        headers.contentType = .jsonAPI

        return .init(response: Response(
            status: .internalServerError,
            headers: headers,
            body: .init(data: try! JSONEncoder().encode(
                API.SingleAPITestDescriptorDocument.ErrorDocument(
                    apiDescription: .none,
                    errors: [
                        .error(.init(
                            id: nil,
                            title: HTTPResponseStatus.internalServerError.reasonPhrase,
                            detail: "Unknown error occurred"
                        ))
                    ]
                )
                ))
            )
        )
    }

    static func jsonBadRequestError<ResponseBodyType: ResponseEncodable>(details: String) -> CannedResponse<ResponseBodyType> {
        var headers = HTTPHeaders()
        headers.contentType = .jsonAPI

        return .init(response: Response(
            status: .badRequest,
            headers: headers,
            body: .init(data: try! JSONEncoder().encode(
                API.SingleAPITestDescriptorDocument.ErrorDocument(
                    apiDescription: .none,
                    errors: [
                        .error(.init(
                            id: nil,
                            title: HTTPResponseStatus.badRequest.reasonPhrase,
                            detail: details
                        ))
                    ]
                )
                ))
            )
        )
    }

    static func jsonNotFoundError<ResponseBodyType: ResponseEncodable>(details: String) -> CannedResponse<ResponseBodyType> {
        var headers = HTTPHeaders()
        headers.contentType = .jsonAPI

        return .init(response: Response(
            status: .notFound,
            headers: headers,
            body: .init(data: try! JSONEncoder().encode(
                API.SingleAPITestDescriptorDocument.ErrorDocument(
                    apiDescription: .none,
                    errors: [
                        .error(.init(
                            id: nil,
                            title: HTTPResponseStatus.notFound.reasonPhrase,
                            detail: details
                        ))
                    ]
                )
                ))
            )
        )
    }
}

// MARK: - SwiftGen Logger
extension Controller {
    typealias Logger = APITestDatabaseLogger
}
