//
//  Route.swift
//  
//
//  Created by Mathew Polzin on 5/2/20.
//

import Vapor
import VaporTypedRoutes

struct Route<Context: RouteContext> {
    let method: HTTPMethod
    let context: Context
    let summary: String?
    let description: String?
    let tags: [String]?
}
