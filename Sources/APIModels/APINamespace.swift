//
//  APINamespace.swift
//  App
//
//  Created by Mathew Polzin on 9/23/19.
//

import Foundation
import JSONAPI
import Poly

extension UUID: JSONAPI.CreatableRawIdType {
    public static func unique() -> UUID {
        return UUID()
    }
}

public enum API {
    public typealias SingleDocument<R: CodablePrimaryResource, I: Include> = JSONAPI.Document<SingleResourceBody<R>, NoMetadata, NoLinks, I, NoAPIDescription, BasicJSONAPIError<String>>
    public typealias BatchDocument<R: CodablePrimaryResource, I: Include> = JSONAPI.Document<ManyResourceBody<R>, NoMetadata, NoLinks, I, NoAPIDescription, BasicJSONAPIError<String>>
}
