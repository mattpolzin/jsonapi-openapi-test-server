//
//  ByteBuffer+ResponseEncodable.swift
//  App
//
//  Created by Mathew Polzin on 12/4/19.
//

import Vapor

extension ByteBuffer: ResponseEncodable {
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response(status: .ok, body: .init(buffer: self))
        return request.eventLoop.makeSucceededFuture(response)
    }
}

extension ByteBuffer: AsyncResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        Response(status: .ok, body: .init(buffer: self))
    }
}
