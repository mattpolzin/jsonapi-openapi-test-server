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
                channel_name TEXT := TG_ARGV[0] || '_updated';
            BEGIN
              PERFORM pg_notify(
                channel_name,
                CAST(NEW.id AS text)
              );
              RETURN NULL;
            END;
            $$ LANGUAGE plpgsql;
        """)
        .run()

        let descriptorTrigger = db.raw("""
            CREATE TRIGGER test_descriptor_event
            AFTER INSERT OR UPDATE ON \(raw: DB.APITestDescriptor.schema)
            FOR EACH ROW
            EXECUTE FUNCTION test_update_notify('\(raw: DB.APITestDescriptor.schema)')
        """)
        .run()

        let messageTrigger = db.raw("""
            CREATE TRIGGER test_message_event
            AFTER INSERT OR UPDATE ON \(raw: DB.APITestMessage.schema)
            FOR EACH ROW
            EXECUTE FUNCTION test_update_notify('\(raw: DB.APITestMessage.schema)')
        """)
        .run()

        return testUpdateNotifyFunction
            .flatMap { descriptorTrigger }
            .flatMap { messageTrigger }
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

        let dropMessageTrigger = db
            .drop(trigger: "test_message_event")
            .table(DB.APITestMessage.schema)
            .run()

        return dropDescriptorTrigger
            .flatMap { dropMessageTrigger }
            .flatMap { dropFunction }
    }
}
