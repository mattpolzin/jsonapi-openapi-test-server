
import App
import AppAPIDocumentation
import Foundation
import Yams

let dummyApp = try app(.detect(), hobbled: true)

let routes = dummyApp.routes

let documentation = try OpenAPIDocs(
    contentConfig: .default(),
    routes: routes
)

dummyApp.shutdown()

let encoder = YAMLEncoder()
encoder.options.sortKeys = true
let documentationString = try encoder.encode(documentation.document)

print(documentationString)
