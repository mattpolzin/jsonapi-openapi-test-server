import Vapor
import VaporTypedRoutes
import VaporOpenAPI
import FluentPostgresDriver
import APITesting

/// Register your application's routes here.
public func addRoutes(_ app: Application, hobbled: Bool = false) throws {

    let sourceController = OpenAPISourceController()

    let testController = APITestController(outputPath: Environment.outPath,
                                           openAPISource: try? .detect())

    let testWatchController: APITestWatchController
    if hobbled {
        testWatchController = APITestWatchController.dummyWatcher()
    } else {
        testWatchController = DatabaseAPITestWatchController(watching: app.db as! PostgresDatabase, with: testController)
    }

    // MARK: - OpenAPI Sources
    app.post("openapi_sources", use: sourceController.create)
        .tags("Sources")
        .summary("Create a new OpenAPI Source")

    app.get("openapi_sources", use: sourceController.index)
        .tags("Sources")
        .summary("Retrieve all OpenAPI Sources")

    app.get("openapi_sources", ":id", use: sourceController.show)
        .tags("Sources")
        .summary("Retrieve a single OpenAPI Source")

    // MARK: - API Testing
    app.post("api_tests", use: testController.create)
        .tags("Testing")
        .summary("Run tests")
        .description(
"""
Running tests is an asynchronous operation. This route will return immediately if it was able to queue up a new test run.

You can monitor the status of your test run with the `GET` `/api_test/{id}` endpoint (the object returned has a `status` attribute).
"""
    )

    app.get("api_tests", use: testController.index)
        .tags("Testing")
        .summary("Retrieve all test results")

    app.get("api_tests", ":id", use: testController.show)
        .tags("Testing")
        .summary("Retrieve a single test result")

    app.webSocket("watch", onUpgrade: testWatchController.watch)
        .tags("Monitoring")
        .summary("Watch for progress on API Tests")
        .description(
"""
This **WebSocket** route will send a message every time a test starts, progresses, finishes, etc.

The message will contain a JSON:API response payload with the APITestDescriptor for the updated test.
"""
    )

    // MARK: Test File Retrieval
    app.get("api_tests", ":id", "files", use: testController.files)
        .tags("Test Files")
        .summary("Retrieve the test files for the given test.")

    // MARK: - Documentation
    app.get("docs", use: DocumentationController.show)
        .tags("Documentation")
        .summary("Show Documentation")
}
