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
        // Register providers first
        app.provider(FluentProvider())

        // Register middleware
        app.register(extension: MiddlewareConfiguration.self) { middlewares, app in
            middlewares.use(ErrorMiddleware.default(environment: app.environment))
            middlewares.use(FileMiddleware(publicDirectory: DirectoryConfiguration.detect().publicDirectory))
        }

        // Configure databases
        app.register(extension: Databases.self, databases)
        app.register(Database.self) { app in
            return app.make(Databases.self).database(.psql)!
        }

        // Configure migrations
        app.register(Migrations.self, migrations)
    }

    // Register routes
    try routes(app)
}
