import Vapor

/// Creates an instance of `Application`. This is called from `main.swift` in the run target.
///
/// - parameters:
///     - env: The Environment to load the app with.
///     - hobbled: Defaults to `false`. If `true`, the app will start
///         without many of the necessary environment variables for running.
///         The assumption inherent in doing so is that you need the app itself
///         to initialize but not actually function. This gives tools like the API
///         generation a chance to inspect the app's routes without requiring a
///         database.
public func app(_ env: Environment, hobbled: Bool = false) throws -> Application {
    var environment = env
    try LoggingSystem.bootstrap(from: &environment)
    let app = Application(environment)
    try configure(app, hobbled: hobbled)
    return app
}
