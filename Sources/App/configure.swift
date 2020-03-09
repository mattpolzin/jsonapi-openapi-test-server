import FluentPostgresDriver
import Fluent
import Vapor
import APITesting

/// Called before your application initializes.
///
/// - parameters:
///     - app: The app to configure.
///     - hobbled: Defaults to `false`. If `true`, the app will start
///         without many of the necessary environment variables for running.
///         The assumption inherent in doing so is that you need the app itself
///         to initialize but not actually function. This gives tools like the API
///         generation a chance to inspect the app's routes without requiring a
///         database.
public func configure(_ app: Application, hobbled: Bool = false) throws {

    if !hobbled {
        // Register middleware
        addMiddleware(app)

        // Configure databases
        try addDatabases(app)

        // Configure migrations
        addMigrations(app)
    }

    // Register routes
    try addRoutes(app)
}
