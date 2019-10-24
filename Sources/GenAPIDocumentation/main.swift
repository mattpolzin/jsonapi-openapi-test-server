
import App
import AppAPIDocumentation
import Foundation
import Yams

let dummyApp = try app(.detect())

let container = try dummyApp.makeContainer().wait()
let routes = try App.routes(container)

let documentation = try OpenAPIDocs(
    contentConfig: .default(),
    routes: routes
)

container.shutdown()

print(try YAMLEncoder().encode(documentation.document))
