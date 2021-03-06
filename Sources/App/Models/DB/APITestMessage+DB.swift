import Vapor
import Foundation
import FluentKit
import SQLKit
import PostgresKit
import OpenAPIReflection
import APIModels
import JSONAPI

extension DB {
    public final class APITestMessage: Model {
        public static let schema = "api_test_messages"

        @ID(key: "id")
        public var id: UUID?

        @Field(key: "created_at")
        public var createdAt: Date

        @Enum(key: "message_type")
        public var messageType: API.MessageType

        @Field(key: "path")
        public var path: String?

        @Field(key: "context")
        public var context: String?

        @Field(key: "message")
        public var message: String

        @Parent(key: "api_test_descriptor_id")
        public var apiTestDescriptor: APITestDescriptor

        public init(testDescriptor: APITestDescriptor, messageType: API.MessageType, path: String?, context: String?, message: String) throws {
            id = UUID()
            createdAt = Date()
            $apiTestDescriptor.id = try testDescriptor.requireID()
            self.messageType = messageType
            self.path = path
            self.context = context
            self.message = message
        }

        /// Used to construct Model from Database
        @available(*, deprecated, renamed: "init(testDescriptor:messageType:message:)")
        public init() {}
    }
}

extension DB.APITestMessage: JSONAPIConvertible {
    typealias JSONAPIModel = API.APITestMessage
    typealias JSONAPIIncludeType = API.SingleAPITestMessageDocument.IncludeType

    func jsonApiResources() throws -> CompoundResource<JSONAPIModel, JSONAPIIncludeType> {
        let testDescriptor = try $apiTestDescriptor.value?.jsonApiResources().primary

        let attributes = API.APITestMessage.Attributes(
            createdAt: createdAt,
            messageType: messageType,
            path: path,
            context: context,
            message: message
        )
        let relationships = API.APITestMessage.Relationships(apiTestDescriptorId: .init(rawValue: $apiTestDescriptor.id))

        return .init(
            primary: API.APITestMessage(
                id: .init(rawValue: try requireID()),
                attributes: attributes,
                relationships: relationships,
                meta: .none,
                links: .none
            ),
            relatives: [testDescriptor.map { .init($0) }].compactMap { $0 }
        )
    }
}
