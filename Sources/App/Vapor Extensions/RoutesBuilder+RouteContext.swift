//
//  RoutesBuilder+RouteContext.swift
//  App
//
//  Created by Mathew Polzin on 10/23/19.
//

import Vapor

extension RoutesBuilder {

    @discardableResult
    public func get<Context, Response>(
        _ path: PathComponent...,
        use closure: @escaping (TypedRequest<Context>) throws -> Response
    ) -> Route
        where Context: RouteContext, Response: ResponseEncodable
    {
        return self.on(.GET, path, use: closure)
    }

    @discardableResult
    public func post<Context, Response>(
        _ path: PathComponent...,
        use closure: @escaping (TypedRequest<Context>) throws -> Response
    ) -> Route
        where Context: RouteContext, Response: ResponseEncodable
    {
        return self.on(.POST, path, use: closure)
    }

    @discardableResult
    public func patch<Context, Response>(
        _ path: PathComponent...,
        use closure: @escaping (TypedRequest<Context>) throws -> Response
    ) -> Route
        where Context: RouteContext, Response: ResponseEncodable
    {
        return self.on(.PATCH, path, use: closure)
    }

    @discardableResult
    public func put<Context, Response>(
        _ path: PathComponent...,
        use closure: @escaping (TypedRequest<Context>) throws -> Response
    ) -> Route
        where Context: RouteContext, Response: ResponseEncodable
    {
        return self.on(.PUT, path, use: closure)
    }

    @discardableResult
    public func delete<Context, Response>(
        _ path: PathComponent...,
        use closure: @escaping (TypedRequest<Context>) throws -> Response
    ) -> Route
        where Context: RouteContext, Response: ResponseEncodable
    {
        return self.on(.DELETE, path, use: closure)
    }

    @discardableResult
    public func on<Context, Response>(
        _ method: HTTPMethod,
        _ path: [PathComponent],
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @escaping (TypedRequest<Context>) throws -> Response
    ) -> Route
        where Context: RouteContext, Response: ResponseEncodable
    {
        let wrappingClosure = { (request: Vapor.Request) -> Response in
            return try closure(.init(underlyingRequest: request))
        }

        let responder = BasicResponder { request in
            if case .collect(let max) = body, request.body.data == nil {
                return request.body.collect(max: max).flatMapThrowing { _ in
                    return try wrappingClosure(request)
                }.encodeResponse(for: request)
            } else {
                return try wrappingClosure(request)
                    .encodeResponse(for: request)
            }
        }

        let route = Route(
            method: method,
            path: path,
            responder: responder,
            requestType: Context.RequestBodyType.self,
            responseType: Context.self
        )

        self.add(route)

        return route
    }
}
