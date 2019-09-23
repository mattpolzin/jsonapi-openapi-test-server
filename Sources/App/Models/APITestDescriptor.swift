import Vapor
import Foundation
import FluentKit
import SQLKit

final class APITestDescriptor: Model {
    typealias IDValue = UUID
    static let schema = "api_test_descriptors"

    @ID(key: "id")
    var id: UUID

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
    init(id: UUID) {
        self.id = id
        createdAt = Date()
        finishedAt = nil
        status = .pending
    }

    /// Used to construct Model from Database
    @available(*, deprecated, renamed: "init(id:)")
    init() {}
}

extension APITestDescriptor {
    enum Status: String, Codable {
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

/// Allows `APITestDescriptor` to be encoded to and decoded from HTTP messages.
extension APITestDescriptor: Content { }

/// Allows `APITestDescriptor` to be used as a dynamic parameter in route definitions.
//extension APITestDescriptor: Parameter { }

struct InitAPITestDescriptorMigration: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("api_test_descriptors")
            .field("id", .uuid, .identifier(auto: false))
            .field("created_at", .datetime, .required)
            .field("finished_at", .datetime)
            .field("status", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("api_test_descriptors").delete()
    }
}
