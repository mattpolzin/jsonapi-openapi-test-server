//
//  APITestProperties+Sampleable.swift
//  
//
//  Created by Mathew Polzin on 5/8/20.
//

import Foundation
import App
import Sampleable
import APIModels

extension API.APITestPropertiesDescription.Attributes: Sampleable {
    public static var sample: API.APITestPropertiesDescription.Attributes {
        .init(createdAt: Date(), apiHostOverride: URL(string: "https://mysite.com")!, parser: .stable)
    }
}

extension API.APITestPropertiesDescription.Relationships: Sampleable {
    public static var sample: API.APITestPropertiesDescription.Relationships {
        .init(openAPISourceId: .init(rawValue: UUID()))
    }
}
