
import Vapor
import FluentPostgresDriver

public func databases(_ container: Container) throws -> Databases {
    var databases = Databases(on: container.eventLoop)
    try databases.postgres(config: Environment.dbConfig())
    return databases
}
