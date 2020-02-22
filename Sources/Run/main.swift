import App
import Vapor

#if DEBUG
import Backtrace
// Do this first
Backtrace.install()
#endif

var environment = try Environment.detect()
try LoggingSystem.bootstrap(from: &environment)

let app = Application(environment)
defer { app.shutdown() }

try configure(app, hobbled: false)

try app.run()
