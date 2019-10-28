import Vapor
import FluentPostgresDriver
import APITesting

/// Register your application's routes here.
public func routes(_ app: Application) throws {
    let testController = try APITestController(outputPath: Environment.outPath,
                                               openAPISource: .detect(),
                                               database: app.make())

    app.post("api_test", use: testController.create)
        .tags("Testing")
        .summary("Run tests")

    app.get("api_test", use: testController.index)
        .tags("Status")
        .summary("Retrieve all test results")

    app.get("api_test", ":id", use: testController.show)
        .tags("Status")
        .summary("Retrieve a single test result")
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
