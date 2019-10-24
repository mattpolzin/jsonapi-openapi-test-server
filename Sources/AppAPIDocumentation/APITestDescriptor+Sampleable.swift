//
//  APITestDescriptor+Sampleable.swift
//  AppAPIDocumentation
//
//  Created by Mathew Polzin on 10/19/19.
//

import Foundation
import App
import Sampleable

extension API.APITestDescriptorDescription.Attributes: Sampleable {
    public static var sample: Self {
        return .init(
            createdAt: Date(),
            finishedAt: Date(),
            status: .passed
        )
    }
}

extension API.APITestDescriptorDescription.Relationships: Sampleable {
    public static var sample: Self {
        return .init(messageIds: [.init(), .init()])
    }
}
