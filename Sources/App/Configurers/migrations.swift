
import FluentPostgresDriver
import Vapor

private let migrationList: [Migration] = [
    InitOpenAPISourceMigration(),
    InitAPITestDescriptorMigration(),
    InitAPITestMessageMigration(),
    TestUpdateNotificationMigration()
]

public func addMigrations(_ app: Application) {
    for migration in migrationList {
        app.migrations.add(migration)
    }
}
