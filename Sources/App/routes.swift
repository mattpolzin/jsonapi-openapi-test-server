import Vapor
import FluentPostgresDriver
import APITesting

extension UUID: LosslessStringConvertible {
    public init?(_ description: String) {
        guard let value = UUID(uuidString: description) else {
            return nil
        }
        self = value
    }
}

/// Register your application's routes here.
public func routes(_ container: Container) throws -> Routes {
    let routes = Routes(eventLoop: container.eventLoop)

    let testController = try APITestController(outputPath: Environment.outPath,
                                               openAPISource: .detect(),
                                               database: container.make())

    routes.post("api_test", use: testController.create)
        .tags("Testing")
        .summary("Run tests")

    routes.get("api_test", use: testController.index)
        .tags("Status")
        .summary("Retrieve all test results")

    routes.get("api_test", ":id", use: testController.show)
        .tags("Status")
        .summary("Retrieve a single test result")

    return routes
}

extension Route {
    @discardableResult
    public func summary(_ summary: String) -> Route {
        userInfo["openapi:summary"] = summary
        return self
    }

    @discardableResult
    public func tags(_ tags: String...) -> Route {
        return self.tags(tags)
    }

    @discardableResult
    public func tags(_ tags: [String]) -> Route {
        userInfo["openapi:tags"] = tags
        return self
    }
}
