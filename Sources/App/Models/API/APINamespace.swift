//
//  APINamespace.swift
//  App
//
//  Created by Mathew Polzin on 9/23/19.
//

import Foundation
import Vapor
import JSONAPI
import Poly

extension UUID: JSONAPI.CreatableRawIdType {
    public static func unique() -> UUID {
        return UUID()
    }
}

extension JSONAPI.Document: Content, RequestDecodable, ResponseEncodable where PrimaryResourceBody: CodableResourceBody, IncludeType: Decodable {}

extension JSONAPI.Document.ErrorDocument: Content, RequestDecodable, ResponseEncodable where PrimaryResourceBody: CodableResourceBody, IncludeType: Decodable {}

extension JSONAPI.Document.SuccessDocument: Content, RequestDecodable, ResponseEncodable where PrimaryResourceBody: CodableResourceBody, IncludeType: Decodable {}

extension Either: Content, RequestDecodable, ResponseEncodable where A: Content, B: Content {}

public enum API {
    public typealias SingleDocument<R: CodablePrimaryResource, I: Include> = JSONAPI.Document<SingleResourceBody<R>, NoMetadata, NoLinks, I, NoAPIDescription, BasicJSONAPIError<String>>
    public typealias BatchDocument<R: CodablePrimaryResource, I: Include> = JSONAPI.Document<ManyResourceBody<R>, NoMetadata, NoLinks, I, NoAPIDescription, BasicJSONAPIError<String>>
}
