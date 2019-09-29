
import Vapor
import FluentPostgresDriver

public func databases(_ databases: inout Databases, _ container: Container) throws {
    try databases.postgres(config: Environment.dbConfig())
}
