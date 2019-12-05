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
    var requestBodyType: Any.Type { get }
    static var responseBodyTuples: [(statusCode: Int, responseBodyType: Any.Type)] { get }
}

public protocol RouteContext: AbstractRouteContext {
    associatedtype RequestBodyType: Decodable

    static var builder: () -> Self { get }
}

extension RouteContext {
    public static func build() -> Self { return .builder() }
}

extension RouteContext {
    public var requestBodyType: Any.Type { return RequestBodyType.self }

    public static var responseBodyTuples: [(statusCode: Int, responseBodyType: Any.Type)] {
        let context = Self.build()

        let mirror = Mirror(reflecting: context)

        let responseContexts = mirror
            .children
            .compactMap { property in property.value as? AbstractResponseContextType }

        return responseContexts
            .map { responseContext in
                var dummyResponse = Response()
                responseContext.configure(&dummyResponse)

                let statusCode = Int(dummyResponse.status.code)

                return (
                    statusCode: statusCode,
                    responseBodyType: responseContext.responseBodyType
                )
        }
    }
}
