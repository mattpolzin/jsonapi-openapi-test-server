//
//  JSONAPIConvertible.swift
//  
//
//  Created by Mathew Polzin on 5/16/20.
//

import Foundation
import JSONAPI

protocol JSONAPIConvertible {
    associatedtype JSONAPIModel: JSONAPI.ResourceObjectType
    associatedtype JSONAPIIncludeType: JSONAPI.Include

    func jsonApiResources() throws -> CompoundResource<JSONAPIModel, JSONAPIIncludeType>
}
