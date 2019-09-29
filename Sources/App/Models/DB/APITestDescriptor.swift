import Vapor
import Foundation
import FluentKit

public final class APITestDescriptor: Model {
    public static let schema = "api_test_descriptors"

    // bit of a hacky way to track whether this resource
    // was created fresh or loaded from the database.
    public let isLoadedFromDb: Bool

    @ID(key: "id")
    public var id: UUID?

    @Field(key: "created_at")
    var createdAt: Date

    @Field(key: "finished_at")
    var finishedAt: Date?

    @Field(key: "status")
    var status: Status

    @Children(from: \.$apiTestDescriptor)
    var messages: [APITestMessage]

    /// Create a new test descriptor. It is strongly recommended that
    /// the id be set to that of the originating API request because
    /// then logging related to the originating request can be easily tied
    /// to logging related to the separate testing tasks.
    public init(id: UUID) {
        isLoadedFromDb = false
        self.id = id
        createdAt = Date()
        finishedAt = nil
        status = .pending
    }

    /// Used to construct Model from Database
    @available(*, deprecated, renamed: "init(id:)")
    public init() {
        isLoadedFromDb = true
    }
}

extension APITestDescriptor {
    public enum Status: String, Codable {
        case pending
        case building
        case running
        case passed
        case failed
    }

    /// Mutates this APIDescriptor to .pending and returns self for chaining.
    public func markPending() -> APITestDescriptor {
        status = .pending
        return self
    }

    /// Mutates this APIDescriptor to .building and returns self for chaining.
    public func markBuilding() -> APITestDescriptor {
        status = .building
        return self
    }

    /// Mutates this APIDescriptor to .running and returns self for chaining.
    public func markRunning() -> APITestDescriptor {
        status = .running
        return self
    }

    /// Mutates this APIDescriptor to .passed and returns self for chaining.
    public func markPassed() -> APITestDescriptor {
        status = .passed
        finishedAt = Date()
        return self
    }

    /// Mutates this APIDescriptor to .failed and returns self for chaining.
    public func markFailed() -> APITestDescriptor {
        status = .failed
        finishedAt = Date()
        return self
    }
}

extension APITestDescriptor {
    func serializable() throws -> (API.APITestDescriptor, [API.APITestMessage]) {
        let relatives: [API.APITestMessage]

        if isLoadedFromDb {
            relatives = try $messages.eagerLoaded().map { try $0.serializable() }
        } else {
            relatives = []
        }

        let attributes = API.APITestDescriptor.Attributes(createdAt: .init(value: createdAt),
                                                          finishedAt: .init(value: finishedAt),
                                                          status: .init(value: status))

        let relationships = API.APITestDescriptor.Relationships(messages: .init(resourceObjects: relatives))

        return (
            API.APITestDescriptor(id: .init(rawValue: try requireID()),
                                  attributes: attributes,
                                  relationships: relationships,
                                  meta: .none,
                                  links: .none),
            relatives
        )
    }
}

/// Allows `APITestDescriptor` to be used as a dynamic parameter in route definitions.
//extension APITestDescriptor: Parameter { }
