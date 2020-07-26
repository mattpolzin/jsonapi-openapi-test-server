
import FluentPostgresDriver
import Vapor

private let migrationList: [Migration] = [
    DB.OpenAPISource.Migrations.Create(),
    DB.APITestProperties.Migrations.Create(),
    DB.APITestDescriptor.Migrations.Create(),
    DB.APITestMessage.Migrations.Create(),
    TestUpdateNotificationMigration(),
    DB.APITestProperties.Migrations.AddParserField()
]

public func addMigrations(_ app: Application) {
    for migration in migrationList {
        app.migrations.add(migration)
    }
}
