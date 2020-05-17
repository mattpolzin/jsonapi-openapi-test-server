//
//  JSONAPIDocument+init.swift
//  
//
//  Created by Mathew Polzin on 5/16/20.
//

import Foundation
import JSONAPI

extension Document where MetaType == NoMetadata, LinksType == NoLinks, APIDescription == NoAPIDescription {
    init(body: PrimaryResourceBody) {
        self.init(
            apiDescription: .none,
            body: body,
            includes: .none,
            meta: .none,
            links: .none
        )
    }
}

extension Document.SuccessDocument where MetaType == NoMetadata, LinksType == NoLinks, APIDescription == NoAPIDescription {
    init(body: PrimaryResourceBody) {
        self.init(
            apiDescription: .none,
            body: body,
            includes: .none,
            meta: .none,
            links: .none
        )
    }
}
