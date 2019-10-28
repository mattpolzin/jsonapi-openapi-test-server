
import App
import AppAPIDocumentation
import Foundation
import Yams

let dummyApp = try app(.detect())

let routes = dummyApp.routes

let documentation = try OpenAPIDocs(
    contentConfig: .default(),
    routes: routes
)

dummyApp.shutdown()

print(try YAMLEncoder().encode(documentation.document))
