//
//  TestUpdateNotificationMigration.swift
//  
//
//  Created by Mathew Polzin on 4/8/20.
//

import SQLKit
import Fluent

public struct TestUpdateNotificationMigration: Migration {
    public func prepare(on database: Database) -> EventLoopFuture<Void> {

        let db = database as! SQLDatabase

        let testUpdateNotifyFunction = db.raw("""
            CREATE FUNCTION test_update_notify()
              RETURNS trigger AS $$
            DECLARE
            BEGIN
              PERFORM pg_notify(
                CAST('test_updated' AS text),
                CAST(NEW.id AS text)
              );
              RETURN NULL;
            END;
            $$ LANGUAGE plpgsql;
        """)
        .run()

        let descriptorTrigger = db.raw("""
            CREATE TRIGGER test_descriptor_event
            AFTER INSERT OR UPDATE ON \(DB.APITestDescriptor.schema)
            FOR EACH ROW
            EXECUTE FUNCTION test_update_notify()
        """)
        .run()

        return testUpdateNotifyFunction
            .flatMap { descriptorTrigger }
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        let db = database as! SQLDatabase

        let dropFunction = db.raw("""
            DROP FUNCTION test_update_notify
        """)
        .run()

        let dropDescriptorTrigger = db
            .drop(trigger: "test_descriptor_event")
            .table(DB.APITestDescriptor.schema)
            .run()

        return dropDescriptorTrigger
            .flatMap { dropFunction }
    }
}
