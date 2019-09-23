
import FluentPostgresDriver
import Vapor

private let migrationList: [Migration] = [
    InitAPITestDescriptorMigration(),
    InitAPITestMessageMigration()
]

public func migrations(_ container: Container) -> Migrations {
    var migrations = Migrations()

    for migration in migrationList {
        migrations.add(migration, to: .psql)
    }

    return migrations
}
