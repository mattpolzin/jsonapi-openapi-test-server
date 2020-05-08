//
//  RouteContext+JSONAPI.swift
//  
//
//  Created by Mathew Polzin on 5/7/20.
//

import VaporTypedRoutes
import Vapor

protocol JSONAPIRouteContext: RouteContext {}
extension JSONAPIRouteContext {
    public static var defaultContentType: HTTPMediaType? { .jsonAPI }
}
