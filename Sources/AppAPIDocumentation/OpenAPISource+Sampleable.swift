//
//  OpenAPISource+Sampleable.swift
//  AppAPIDocumentation
//
//  Created by Mathew Polzin on 12/10/19.
//

import Foundation
import App
import Sampleable

extension API.OpenAPISourceDescription.Attributes: Sampleable {
    public static var sample: Self {
        return .init(
            createdAt: Date(),
            uri: "https://api.domain.com/docs",
            sourceType: .url
        )
    }
}
