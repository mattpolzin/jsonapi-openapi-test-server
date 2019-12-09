//
//  RouteContext.swift
//  App
//
//  Created by Mathew Polzin on 10/23/19.
//

import Vapor

public struct EmptyRequestBody: Decodable {}
public struct EmptyResponseBody: Encodable {}

extension EmptyResponseBody: ResponseEncodable {
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        return "".encodeResponse(for: request)
    }
}

public protocol AbstractRouteContext {
    static var requestBodyType: Any.Type { get }
    static var requestQueryParams: [AbstractQueryParam] { get }

    static var responseBodyTuples: [(statusCode: Int, contentType: HTTPMediaType?, responseBodyType: Any.Type)] { get }
}

public protocol RouteContext: AbstractRouteContext {
    associatedtype RequestBodyType: Decodable

    static var shared: Self { get }
}

extension RouteContext {
    public static var requestBodyType: Any.Type { return RequestBodyType.self }

    public static var responseBodyTuples: [(statusCode: Int, contentType: HTTPMediaType?, responseBodyType: Any.Type)] {
        let context = Self.shared

        let mirror = Mirror(reflecting: context)

        let responseContexts = mirror
            .children
            .compactMap { property in property.value as? AbstractResponseContextType }

        return responseContexts
            .map { responseContext in
                var dummyResponse = Response()
                responseContext.configure(&dummyResponse)

                let statusCode = Int(dummyResponse.status.code)
                let contentType = dummyResponse.headers.contentType

                return (
                    statusCode: statusCode,
                    contentType: contentType,
                    responseBodyType: responseContext.responseBodyType
                )
        }
    }

    public static var requestQueryParams: [AbstractQueryParam] {
        let context = Self.shared

        let mirror = Mirror(reflecting: context)

        return mirror
            .children
            .compactMap { property in property.value as? AbstractQueryParam }
    }
}
