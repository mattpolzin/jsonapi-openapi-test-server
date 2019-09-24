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

extension JSONAPI.Document: Content, RequestDecodable, ResponseEncodable where PrimaryResourceBody: ResourceBody, IncludeType: Decodable {}

extension Either: Content, RequestDecodable, ResponseEncodable where A: Content, B: Content {}

enum API {}
