import FluentPostgresDriver
import Fluent
import Vapor
import APITesting

/// Called before your application initializes.
public func configure(_ app: Application) throws {
    // Register providers first
    app.provider(FluentProvider())

    // Register middleware
    app.register(extension: MiddlewareConfiguration.self) { middlewares, app in
        middlewares.use(ErrorMiddleware.default(environment: app.environment))
    }

    // Configure databases
    app.register(extension: Databases.self, databases)
    app.register(Database.self) { app in
        return app.make(Databases.self).database(.psql)!
    }

    // Configure migrations
    app.register(Migrations.self, migrations)

    // Register routes
    try routes(app)
}
