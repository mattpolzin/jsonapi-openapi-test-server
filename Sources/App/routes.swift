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
    routes.get("api_test", use: testController.index)
    routes.get("api_test", ":id", use: testController.show)

    return routes
}
