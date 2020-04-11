//
//  APITestMessage+Sampleable.swift
//  AppAPIDocumentation
//
//  Created by Mathew Polzin on 10/19/19.
//

import Foundation
import App
import Sampleable
import APIModels

extension API.APITestMessageDescription.Attributes: Sampleable {
    public static var sample: Self {
        return .init(
            createdAt: Date(),
            messageType: .success,
            path: nil,
            context: nil,
            message: "Test Succeeded"
        )
    }
}

extension API.APITestMessageDescription.Relationships: Sampleable {
    public static var sample: Self {
        return .init(apiTestDescriptorId: .init())
    }
}
