//
//  JSONAPIConvertible.swift
//  
//
//  Created by Mathew Polzin on 5/16/20.
//

import Foundation
import JSONAPI

public struct CompoundResource<JSONAPIModel: JSONAPI.ResourceObjectType, JSONAPIIncludeType: JSONAPI.Include>: Equatable {
    public let primary: JSONAPIModel
    public let relatives: [JSONAPIIncludeType]

    public init(primary: JSONAPIModel, relatives: [JSONAPIIncludeType]) {
        self.primary = primary
        self.relatives = relatives
    }
}

protocol JSONAPIConvertible {
    associatedtype JSONAPIModel: JSONAPI.ResourceObjectType
    associatedtype JSONAPIIncludeType: JSONAPI.Include

    func jsonApiResources() throws -> CompoundResource<JSONAPIModel, JSONAPIIncludeType>
}
