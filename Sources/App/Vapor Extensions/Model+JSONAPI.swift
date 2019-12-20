//
//  Model+JSONAPI.swift
//  App
//
//  Created by Mathew Polzin on 12/19/19.
//

import Vapor
import JSONAPI
import FluentKit

extension Model {
    public static func find<ID: IdType>(_ id: ID?, on database: Database) -> EventLoopFuture<Self?>
        where ID.RawType == IDValue {
            return find(id.rawValue, on: database)
    }
}
