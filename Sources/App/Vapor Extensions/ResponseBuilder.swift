//
//  ResponseBuilder.swift
//  App
//
//  Created by Mathew Polzin on 10/23/19.
//

import Vapor

@dynamicMemberLookup
public struct ResponseBuilder<Context: RouteContext> {
    public let context: Context = .shared
    private unowned var request: TypedRequest<Context>

    public subscript<T>(dynamicMember path: KeyPath<Context, ResponseContext<T>>) -> ResponseEncoder<T> {
        return .init(request: request, modifiers: [context[keyPath: path].configure])
    }

    public subscript<T>(dynamicMember path: KeyPath<Context, CannedResponse<T>>) -> EventLoopFuture<Response> {
        return request.eventLoop.makeSucceededFuture(context[keyPath: path].response)
    }

    public init(request: TypedRequest<Context>) {
        self.request = request
    }

    public struct ResponseEncoder<ResponseBodyType: ResponseEncodable> {
        private let request: TypedRequest<Context>
        private let modifiers: [(inout Response) -> Void]

        public func encode(_ response: ResponseBodyType) -> EventLoopFuture<Response> {
            let encodedResponseFuture = response
                .encodeResponse(for: request.underlyingRequest)

            return encodedResponseFuture.map { encodedResponse in
                self.modifiers
                    .reduce(into: encodedResponse) { resp, mod in mod(&resp) }
            }
        }

        init(request: TypedRequest<Context>, modifiers: [(inout Response) -> Void]) {
            self.request = request
            self.modifiers = modifiers
        }
    }
}
