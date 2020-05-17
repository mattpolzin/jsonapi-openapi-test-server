import Vapor
import Foundation
import FluentKit
import APITesting
import OpenAPIReflection
import APIModels
import JSONAPI

extension DB {
    public final class APITestDescriptor: Model {
        public static let schema = "api_test_descriptors"

        @ID(key: "id")
        public var id: UUID?

        @Field(key: "created_at")
        public var createdAt: Date

        @Field(key: "finished_at")
        public var finishedAt: Date?

        @Enum(key: "status")
        public var status: API.TestStatus

        @Children(for: \.$apiTestDescriptor)
        public var messages: [APITestMessage]

        @Parent(key: "test_properties_id")
        public var testProperties: APITestProperties

        /// Create a new test descriptor. It is strongly recommended that
        /// the id be set to that of the originating API request because
        /// then logging related to the originating request can be easily tied
        /// to logging related to the separate testing tasks.
        public init(id: UUID, testProperties: APITestProperties) throws {
            self.id = id
            createdAt = Date()
            finishedAt = nil
            status = .pending
            $testProperties.id = try testProperties.requireID()
        }

        /// Used to construct Model from Database
        @available(*, deprecated, renamed: "init(id:)")
        public init() {}
    }
}

extension DB.APITestDescriptor: TestProgressTracker {

    /// Mutates this APIDescriptor to .pending and returns self for chaining.
    public func markPending() -> DB.APITestDescriptor {
        status = .pending
        return self
    }

    /// Mutates this APIDescriptor to .building and returns self for chaining.
    public func markBuilding() -> DB.APITestDescriptor {
        status = .building
        return self
    }

    /// Mutates this APIDescriptor to .running and returns self for chaining.
    public func markRunning() -> DB.APITestDescriptor {
        status = .running
        return self
    }

    /// Mutates this APIDescriptor to .passed and returns self for chaining.
    public func markPassed() -> DB.APITestDescriptor {
        status = .passed
        finishedAt = Date()
        return self
    }

    /// Mutates this APIDescriptor to .failed and returns self for chaining.
    public func markFailed() -> DB.APITestDescriptor {
        status = .failed
        finishedAt = Date()
        return self
    }
}

extension DB.APITestDescriptor: JSONAPIConvertible {
    typealias JSONAPIModel = API.APITestDescriptor
    typealias JSONAPIIncludeType = API.SingleAPITestDescriptorDocument.IncludeType

    func jsonApiResources() throws -> CompoundResource<JSONAPIModel, JSONAPIIncludeType> {
        let propertiesId = API.APITestProperties.Id(rawValue: $testProperties.id)
        let properties = try $testProperties.value?.jsonApiResources()

        let messages = try $messages
            .value?
            .map { try $0.jsonApiResources().primary }
            ?? []

        let attributes = API.APITestDescriptor.Attributes(
            createdAt: createdAt,
            finishedAt: finishedAt,
            status: status
        )

        let relationships = API.APITestDescriptor.Relationships(
            testPropertiesId: propertiesId,
            messageIds: messages.map { $0.id }
        )

        let relatives: [JSONAPIIncludeType] = [
            properties.map { .init($0.primary) },
            properties?.relatives.compactMap { $0.a }.first.map { .init($0) },
        ].compactMap { $0 } + messages.map { JSONAPIIncludeType($0) }

        return .init(
            primary: API.APITestDescriptor(
                id: .init(rawValue: try requireID()),
                attributes: attributes,
                relationships: relationships,
                meta: .none,
                links: .none
            ),
            relatives: relatives
        )
    }
}
