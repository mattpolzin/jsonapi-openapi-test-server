
import FluentPostgresDriver
import Vapor

private let migrationList: [Migration] = [
    InitAPITestDescriptorMigration(),
    InitAPITestMessageMigration()
]

public func addMigrations(_ app: Application) {
    for migration in migrationList {
        app.migrations.add(migration)
    }
}
