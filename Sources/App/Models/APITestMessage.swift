import Vapor
import Foundation
import FluentKit
import SQLKit
import PostgresKit

final class APITestMessage: Model {
    static let schema = "api_test_messages"

    @ID(key: "id")
    var id: UUID

    @Field(key: "created_at")
    var createdAt: Date

    @Field(key: "message_type")
    var messageType: MessageType

    @Field(key: "message")
    var message: String

    @Parent(key: "api_test_descriptor_id")
    var apiTestDescriptor: APITestDescriptor

    init(testDescriptor: APITestDescriptor, messageType: MessageType, message: String) {
        id = UUID()
        createdAt = Date()
        apiTestDescriptor = testDescriptor
        self.messageType = messageType
        self.message = message
    }

    /// Used to construct Model from Database
    @available(*, deprecated, renamed: "init(testDescriptor:messageType:message:)")
    init() {}
}

extension APITestMessage {
    enum MessageType: String, Codable {
        case debug
        case info
        case warning
        case success
        case error
    }
}

/// Allows `APITestDescriptor` to be encoded to and decoded from HTTP messages.
extension APITestMessage: Content { }

/// Allows `APITestDescriptor` to be used as a dynamic parameter in route definitions.
//extension APITestDescriptor: Parameter { }

struct InitAPITestMessageMigration: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {

        return database.schema("api_test_messages")
            .field("id", .uuid, .identifier(auto: false))
            .field("created_at", .datetime, .required)
            .field("message_type", .string, .required)
            .field("message", .string, .required)
            .field("api_test_descriptor_id", .uuid,
                   .custom(SQLColumnConstraint.references(APITestDescriptor.schema, "id",
                                                          onDelete: .cascade,
                                                          onUpdate: .cascade)))
            .create()
            .map { _ -> SQLDatabase? in database as? SQLDatabase }
            .optionalFlatMap { sqlDb in
                // super unforunate thing has to be done
                // because multiple column constraints currently
                // fail above.
                sqlDb.raw("ALTER TABLE api_test_messages ALTER COLUMN api_test_descriptor_id SET NOT NULL")
                    .run()
            }.transform(to: ())
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("api_test_messages").delete()
    }
}
