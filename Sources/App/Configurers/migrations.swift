
import FluentPostgresDriver
import Vapor

private let migrationList: [Migration] = [
    OpenAPISourceMigration_Init(),
    APITestPropertiesMigration_Init(),
    APITestDescriptorMigration_Init(),
    APITestMessageMigration_Init(),
    TestUpdateNotificationMigration()
]

public func addMigrations(_ app: Application) {
    for migration in migrationList {
        app.migrations.add(migration)
    }
}
