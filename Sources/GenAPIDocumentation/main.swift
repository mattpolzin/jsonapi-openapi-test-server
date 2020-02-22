
import Vapor
import App
import AppAPIDocumentation
import Foundation
import Yams

var environment = try Environment.detect()
try LoggingSystem.bootstrap(from: &environment)

let dummyApp = Application(environment)
defer { dummyApp.shutdown() }

try configure(dummyApp, hobbled: true)

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
