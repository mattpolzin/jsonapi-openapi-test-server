import Vapor

/// Creates an instance of `Application`. This is called from `main.swift` in the run target.
public func app(_ env: Environment) throws -> Application {
    var environment = env
    try LoggingSystem.bootstrap(from: &environment)
    let app = Application(environment: environment)
    try configure(app)
    return app
}
