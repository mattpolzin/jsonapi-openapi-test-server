//
//  ResponseContext.swift
//  App
//
//  Created by Mathew Polzin on 10/23/19.
//

import Vapor

public protocol AbstractResponseContextType {
    var configure: (inout Response) -> Void { get }
    var responseBodyType: Any.Type { get }
}

public protocol ResponseContextType: AbstractResponseContextType {
    associatedtype ResponseBodyType: ResponseEncodable
}

extension ResponseContextType {
    public var responseBodyType: Any.Type { return ResponseBodyType.self }
}

public struct ResponseContext<ResponseBodyType: ResponseEncodable>: ResponseContextType {
    public let configure: (inout Response) -> Void

    init(_ configure: @escaping (inout Response) -> Void) {
        self.configure = { response in
            configure(&response)
        }
    }
}

public struct CannedResponse<ResponseBodyType: ResponseEncodable>: ResponseContextType {
    public let configure: (inout Response) -> Void
    public let response: Response

    init(response cannedResponse: Response) {
        self.response = cannedResponse
        self.configure = { response in
            response = cannedResponse
        }
    }
}
