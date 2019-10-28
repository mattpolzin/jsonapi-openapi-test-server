
import Vapor
import FluentPostgresDriver

public func databases(_ databases: inout Databases, _ app: Application) throws {
    try databases.postgres(configuration: Environment.dbConfig(),
                           poolConfiguration: app.make(),
                           on: app.make())
}
