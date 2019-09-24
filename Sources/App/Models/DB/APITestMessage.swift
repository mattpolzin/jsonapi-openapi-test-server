import Vapor
import Foundation
import FluentKit
import SQLKit
import PostgresKit
import JSONAPI

final class APITestMessage: Model {
    static let schema = "api_test_messages"

    @ID(key: "id")
    var id: UUID?

    @Field(key: "created_at")
    var createdAt: Date

    @Field(key: "message_type")
    var messageType: MessageType

    @Field(key: "context")
    var context: String?

    @Field(key: "message")
    var message: String

    @Parent(key: "api_test_descriptor_id")
    var apiTestDescriptor: APITestDescriptor

    init(testDescriptor: APITestDescriptor, messageType: MessageType, context: String?, message: String) throws {
        id = UUID()
        createdAt = Date()
        $apiTestDescriptor.id = try testDescriptor.requireID()
        self.messageType = messageType
        self.context = context
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

extension APITestMessage {
    func serializable() throws -> API.APITestMessage {
        let attributes = API.APITestMessage.Attributes(createdAt: .init(value: createdAt),
                                                       messageType: .init(value: messageType),
                                                       context: .init(value: context),
                                                       message: .init(value: message))
        let relationships = API.APITestMessage.Relationships(apiTestDescriptor: .init(id: .init(rawValue: $apiTestDescriptor.id)))

        return API.APITestMessage(id: .init(rawValue: try requireID()),
                                  attributes: attributes,
                                  relationships: relationships,
                                  meta: .none,
                                  links: .none)
    }
}

/// Allows `APITestDescriptor` to be used as a dynamic parameter in route definitions.
//extension APITestDescriptor: Parameter { }
