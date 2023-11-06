//
//  File.swift
//  
//
//  Created by Mathew Polzin on 4/8/20.
//

import Foundation
import JSONAPI
import APIModels
import Vapor
import Fluent
import Poly

extension JSONAPI.Document: Content, RequestDecodable, AsyncRequestDecodable, ResponseEncodable, AsyncResponseEncodable where PrimaryResourceBody: CodableResourceBody, IncludeType: Decodable {}

extension JSONAPI.Document.ErrorDocument: Content, RequestDecodable, AsyncRequestDecodable, ResponseEncodable, AsyncResponseEncodable where PrimaryResourceBody: CodableResourceBody, IncludeType: Decodable {}

extension JSONAPI.Document.SuccessDocument: Content, RequestDecodable, AsyncRequestDecodable, ResponseEncodable, AsyncResponseEncodable where PrimaryResourceBody: CodableResourceBody, IncludeType: Decodable {}

extension Either: Content, RequestDecodable, AsyncRequestDecodable, ResponseEncodable, AsyncResponseEncodable where A: Content, B: Content {}
