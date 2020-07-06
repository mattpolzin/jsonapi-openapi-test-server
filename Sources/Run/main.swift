import App
import Vapor

var environment = try Environment.detect()
try LoggingSystem.bootstrap(from: &environment)

let app = Application(environment)
defer { app.shutdown() }

app.logger.info("Starting Test Server with \(System.coreCount) CPU cores available.")

try configure(app, hobbled: false)

try app.run()
