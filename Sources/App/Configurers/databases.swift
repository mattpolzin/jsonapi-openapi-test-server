
import Vapor
import FluentPostgresDriver

public func addDatabases(_ app: Application) throws {
    try app.databases.use(
        .postgres(
            configuration: Environment.dbConfig()
        ),
        as: .psql,
        isDefault: true
    )
}
