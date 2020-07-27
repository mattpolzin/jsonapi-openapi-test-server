import App
import Vapor

var environment = try Environment.detect()
try LoggingSystem.bootstrap(from: &environment)

let app = Application(environment)
defer { app.shutdown() }

app.logger.info("\(System.coreCount) CPU cores available.")
app.logger.info("Will run \(Environment.concurrentTests) concurrent tests.")

try configure(app, hobbled: false)

try app.run()
