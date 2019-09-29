import FluentPostgresDriver
import Fluent
import Vapor
import APITesting

/// Called before your application initializes.
public func configure(_ services: inout Services) throws {
    // Register providers first
    services.provider(FluentProvider())

    // Register routes
    services.register(Routes.self, routes)

    // Register middleware
    services.register(MiddlewareConfiguration.self) { container in
        var middlewares = MiddlewareConfiguration()
        middlewares.use(ErrorMiddleware.default(environment: container.environment)) // Catches errors and converts to HTTP response
        return middlewares
    }

    // Configure databases
    services.register(Databases.self, databases)
    services.register(Database.self) { container in
        return try container.make(Databases.self).database(.psql)!
    }

    // Configure migrations
    services.register(Migrations.self, migrations)

    // Commands
    services.register(APITestCommand.self) { _ in
        return try .init()
    }
    services.extend(CommandConfiguration.self) { commands, container in
        try commands.use(container.make(APITestCommand.self), as: "test")
    }
}
