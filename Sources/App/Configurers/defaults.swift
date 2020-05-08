//
//  defaults.swift
//  
//
//  Created by Mathew Polzin on 5/7/20.
//

import Vapor

public func configureDefaults(for app: Application) throws {
    ContentConfiguration.global.use(decoder: JSONDecoder.custom(dates: .iso8601), for: .jsonAPI)
}
