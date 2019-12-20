//
//  TypedRequest.swift
//  App
//
//  Created by Mathew Polzin on 10/22/19.
//

import Vapor
import NIO

@dynamicMemberLookup
public final class TypedRequest<Context: RouteContext> {
    private let request: Request

    public private(set) lazy var query: Query = Query(request: self)
    public private(set) lazy var response = ResponseBuilder<Context>(request: self)

    public subscript<T>(dynamicMember path: KeyPath<Request, T>) -> T {
        return request[keyPath: path]
    }

    public var underlyingRequest: Request { return request }

    public init(underlyingRequest: Request) {
        request = underlyingRequest
    }

    public func decodeBody(using decoder: ContentDecoder) throws -> Context.RequestBodyType {
        return try request.content.decode(Context.RequestBodyType.self, using: decoder)
    }

    public func decodeBody() throws -> Context.RequestBodyType {
        return try request.content.decode(Context.RequestBodyType.self)
    }
}

extension TypedRequest {

    @dynamicMemberLookup
    public final class Query {
        private unowned var typedRequest: TypedRequest
        private let context: Context = .shared

        init(request: TypedRequest) {
            self.typedRequest = request
        }

        private func getString(at name: String) -> String? {
            return typedRequest
                .underlyingRequest
                .query[String.self, at: name]
        }

        private func getStringArray(at name: String) -> [String]? {
            return getString(at: name)?
                .split(separator: ",")
                .map(String.init)
        }

        /// Get a single query value
        public subscript<T: LosslessStringConvertible>(dynamicMember path: KeyPath<Context, QueryParam<T>>) -> T? {
            return getString(at: context[keyPath: path].name)
                .flatMap(T.init) ?? context[keyPath: path].defaultValue
        }

        /// Get an array of values
        public subscript<T: LosslessStringConvertible>(dynamicMember path: KeyPath<Context, QueryParam<[T]>>) -> [T]? {
            return getStringArray(at: context[keyPath: path].name)?
                .compactMap(T.init) ?? context[keyPath: path].defaultValue
        }

        // TODO: add better support for dictionary
        //      needs modifications to or replacement of the default
        //      parser which throws fatal error if requesting a path
        //      that is not in the query params.
//        public subscript(dynamicMember path: KeyPath<Context, NestedQueryParam<String>>) -> String? {
//            return typedRequest
//                .underlyingRequest
//                .query[String.self, at: context[keyPath: path].path]
//                ?? context[keyPath: path].defaultValue
//        }
    }
}
