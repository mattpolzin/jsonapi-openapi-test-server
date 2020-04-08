import App
import Vapor

var environment = try Environment.detect()
try LoggingSystem.bootstrap(from: &environment)

let app = Application(environment)
defer { app.shutdown() }

try configure(app, hobbled: false)

try app.run()
