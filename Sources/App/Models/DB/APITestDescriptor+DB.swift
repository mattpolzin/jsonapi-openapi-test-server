import Vapor
import Foundation
import FluentKit
import APITesting
import OpenAPIReflection

extension DB {
    public final class APITestDescriptor: Model {
        public static let schema = "api_test_descriptors"

        @ID(key: "id")
        public var id: UUID?

        @Field(key: "created_at")
        var createdAt: Date

        @Field(key: "finished_at")
        var finishedAt: Date?

        @Field(key: "status")
        var status: Status

        @Children(for: \.$apiTestDescriptor)
        var messages: [APITestMessage]

        @Parent(key: "openapi_source_id")
        var openAPISource: OpenAPISource

        /// Create a new test descriptor. It is strongly recommended that
        /// the id be set to that of the originating API request because
        /// then logging related to the originating request can be easily tied
        /// to logging related to the separate testing tasks.
        public init(id: UUID, openAPISource: OpenAPISource) throws {
            self.id = id
            createdAt = Date()
            finishedAt = nil
            status = .pending
            $openAPISource.id = try openAPISource.requireID()
        }

        /// Used to construct Model from Database
        @available(*, deprecated, renamed: "init(id:)")
        public init() {}
    }
}

extension DB.APITestDescriptor: TestProgressTracker {
    public enum Status: String, Codable, CaseIterable, AnyJSONCaseIterable {
        case pending
        case building
        case running
        case passed
        case failed
    }

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

extension DB.APITestDescriptor {
    func serializable() throws -> (descriptor: API.APITestDescriptor, source: API.OpenAPISource?, message: [API.APITestMessage]) {

        let sourceId = API.OpenAPISource.Id(rawValue: $openAPISource.id)
        let source = try $openAPISource.value?.serializable()

        let messages = try $messages
            .value?
            .map { try $0.serializable() }
            ?? []

        let attributes = API.APITestDescriptor.Attributes(
            createdAt: createdAt,
            finishedAt: finishedAt,
            status: status
        )

        let relationships = API.APITestDescriptor.Relationships(
            sourceId: sourceId,
            messageIds: messages.map { $0.id }
        )

        return (
            API.APITestDescriptor(
                id: .init(rawValue: try requireID()),
                attributes: attributes,
                relationships: relationships,
                meta: .none,
                links: .none
            ),
            source,
            messages
        )
    }
}
