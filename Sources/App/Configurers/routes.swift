import Vapor
import VaporTypedRoutes
import VaporOpenAPI
import FluentPostgresDriver
import APITesting

/// Register your application's routes here.
public func addRoutes(_ app: Application, hobbled: Bool = false) throws {

    // MARK: - OpenAPI Sources
    let sourceController = OpenAPISourceController()

    sourceController.mount(on: app, at: "openapi_sources")

    let defaultOpenAPISource = try? OpenAPISource.detect()


    // MARK: - API Test Properties
    let testPropertiesController = APITestPropertiesController(
        openAPISource: defaultOpenAPISource
    )

    testPropertiesController.mount(on: app, at: "api_test_properties")

    // MARK: - API Testing
    let testController = APITestController(
        outputPath: Environment.outPath,
        openAPISource: defaultOpenAPISource
    )

    testController.mount(on: app, at: "api_tests")

    // MARK: - Watching (via WebSockets)
    let testWatchController: APITestWatchController
    if hobbled {
        testWatchController = .dummyWatcher()
    } else {
        testWatchController = DatabaseAPITestWatchController(watching: app.db as! PostgresDatabase, with: testController)
    }

    testWatchController.mount(on: app, at: "watch")

    // MARK: - Documentation
    DocumentationController.mount(on: app, at: "docs")
}
