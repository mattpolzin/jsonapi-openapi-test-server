//import FluentSQLite
import Vapor

/// Called before your application initializes.
public func configure(_ services: inout Services) throws {
    // Register providers first
//    try services.register(FluentSQLiteProvider())

    // Register routes
    services.register(Routes.self, routes)

    // Register middleware
    services.register(MiddlewareConfiguration.self) { container in
        var middlewares = MiddlewareConfiguration()
        // middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
        middlewares.use(ErrorMiddleware.default(environment: container.environment)) // Catches errors and converts to HTTP response
        return middlewares
    }

    // Configure a SQLite database
//    let sqlite = try SQLiteDatabase(storage: .memory)

    // Register the configured SQLite database to the database config.
//    var databases = DatabasesConfig()
//    databases.add(database: sqlite, as: .sqlite)
//    services.register(databases)

    // Configure migrations
//    var migrations = MigrationConfig()
//    migrations.add(model: Todo.self, database: .sqlite)
//    services.register(migrations)
}
