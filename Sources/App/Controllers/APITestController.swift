import Vapor
import VaporTypedRoutes
import FluentKit
import SwiftGen
import APITesting
import JSONAPI
import struct Logging.Logger
import APIModels

/// Controls basic CRUD operations on API Tests.
final class APITestController: Controller {

    static let zipPathPrefix = Environment.archivesPath
    let outputPath: String
    let defaultOpenAPISource: OpenAPISource?
    let testEventLoopGroup: MultiThreadedEventLoopGroup

    init(outputPath: String,
         openAPISource: OpenAPISource?) {
        self.outputPath = outputPath
        self.defaultOpenAPISource = openAPISource
        self.testEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    deinit {
        try! testEventLoopGroup.syncShutdownGracefully()
    }

    private func testEventLoop() -> EventLoop {
        return testEventLoopGroup.next()
    }

    private func zipPath(for test: DB.APITestDescriptor) -> String {
        return Self.zipPathPrefix
            + "/\(test.id!.uuidString).zip"
    }

    private func testLogPath(for test: DB.APITestDescriptor) -> String {
        return Self.zipPathPrefix
            + "/\(test.id!.uuidString).log"
    }

    private func outPath(for test: DB.APITestDescriptor) -> String {
        return self.outputPath
            + "/\(test.id!.uuidString)/"
    }
}

// MARK: - Routes
extension APITestController {
    /// Returns a list of all `APITestDescriptor`s.
    func index(_ req: TypedRequest<IndexContext>) throws -> EventLoopFuture<Response> {
        let shouldIncludeMessages = req.query.include?
            .contains("messages")
            ?? false
        let shouldIncludeProperties = req.query.include?
            .contains("testProperties")
            ?? false
        let shouldIncludeSource = req.query.include?
            .contains("testProperties.openAPISource")
            ?? false

        return indexResults(
            shouldIncludeMessages: shouldIncludeMessages,
            shouldIncludeProperties: (shouldIncludeProperties, alsoIncludeSource: shouldIncludeSource),
            db: req.db
        )
            .flatMap(req.response.success.encode)
    }

    func indexResults(shouldIncludeMessages: Bool, shouldIncludeProperties: (Bool, alsoIncludeSource: Bool), db: Database) -> EventLoopFuture<API.BatchAPITestDescriptorDocument.SuccessDocument> {
        return API.batchAPITestDescriptorResponse(
            query: DB.APITestDescriptor.query(on: db),
            includeProperties: shouldIncludeProperties,
            includeMessages: shouldIncludeMessages
        )
    }

    func show(_ req: TypedRequest<ShowContext>) throws -> EventLoopFuture<Response> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            return req.response.badRequest
        }

        let shouldIncludeMessages = req.query.include?
            .contains("messages")
            ?? false
        let shouldIncludeProperties = req.query.include?
            .contains("testProperties")
            ?? false
        let shouldIncludeSource = req.query.include?
            .contains("testProperties.openAPISource")
            ?? false

        return showResults(
            id: id,
            shouldIncludeMessages: shouldIncludeMessages,
            shouldIncludeProperties: (shouldIncludeProperties, alsoIncludeSource: shouldIncludeSource),
            db: req.db
        )
        .flatMap(req.response.success.encode)
    }

    func showResults(id: UUID, shouldIncludeMessages: Bool, shouldIncludeProperties: (Bool, alsoIncludeSource: Bool), db: Database) -> EventLoopFuture<API.SingleAPITestDescriptorDocument.SuccessDocument> {
        let query = DB.APITestDescriptor.query(on: db)
            .filter(\.$id == id)

        return API.singleAPITestDescriptorResponse(
            query: query,
            includeProperties: shouldIncludeProperties,
            includeMessages: shouldIncludeMessages
        )
    }

    func files(_ req: TypedRequest<FilesContext>) throws -> EventLoopFuture<Response> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            return req.response.badRequest
        }

        let query = DB.APITestDescriptor.query(on: req.db)
            .filter(\.$id == id)

        return query.first()
            .unwrap(or: Abort(.notFound))
            .map(self.zipPath)
            .flatMap(req.fileio.collectFile)
            .flatMap(req.response.success.encode)
    }

    func logs(_ req: TypedRequest<LogsContext>) throws -> EventLoopFuture<Response> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            return req.response.badRequest
        }

        let query = DB.APITestDescriptor.query(on: req.db)
            .filter(\.$id == id)

        return query.first()
            .unwrap(or: Abort(.notFound))
            .map(self.testLogPath)
            .flatMap(req.fileio.collectFile)
            .flatMap(req.response.success.encode)
    }

    /// Create an `APITestDescriptor` and run new tests.
    func create(_ req: TypedRequest<CreateContext>) throws -> EventLoopFuture<Response> {
        let reqUUIDGuess = req
            .logger[metadataKey: "uuid"]
            .map { $0.description }
            .flatMap(UUID.init(uuidString:))

        let requestedTestProperties = req.eventLoop.makeSucceededFuture(())
            .flatMapThrowing { try req.decodeBody().primaryResource.value }
            .map { $0 ~> \.testProperties }
            .optionalFlatMap { Self.givenProperties(with: $0, on: req.db) }

        let futureTestProperties: EventLoopFuture<(DB.APITestProperties, DB.OpenAPISource)> = requestedTestProperties.flatMap {
            if let properties = $0 {
                return req.eventLoop.makeSucceededFuture(properties)
            }

            return self.defaultProperties(on: req.db)
        }

        let descriptorFuture = futureTestProperties.flatMapThrowing { (testProperties, source) in
            (
                try DB.APITestDescriptor(
                    id: reqUUIDGuess ?? UUID(),
                    testProperties: testProperties
                ),
                testProperties,
                source
            )
        }

        let savedDescriptorTuple = descriptorFuture
            .flatMap { $0.0.save(on: req.db) }
            .flatMap { descriptorFuture }

        // Kick tests off asynchronously
        savedDescriptorTuple.whenSuccess { [weak self] (descriptor, properties, source) in

            // this just fails if the controller has been released from memory
            // which we consider possible here because this whole process is async
            // and independent of the API request completion.
            guard let self = self else { return }

            let outPath = self.outPath(for: descriptor)
            let testLogPath = self.testLogPath(for: descriptor)
            let zipPath = self.zipPath(for: descriptor)
            let eventLoop = self.testEventLoop()

            let swiftGenSource = OpenAPISource(source)
            let testProperties = APITestProperties(
                openAPISource: swiftGenSource,
                apiHostOverride: properties.apiHostOverride
            )

            let testLogger = Controller.Logger(
                systemLogger: req.logger,
                descriptor: descriptor,
                eventLoop: eventLoop,
                database: req.db
            )

            let _ = APITestCommand.kickTestsOff(
                testProgressTracking: (descriptor, req.db),
                testProperties: testProperties,
                outPath: outPath,
                zipPath: zipPath,
                testLogPath: testLogPath,
                eventLoop: eventLoop,
                requestLogger: req.logger,
                testLogger: testLogger
            )
        }

        return savedDescriptorTuple.flatMapThrowing { (descriptor, _, _) in
            API.SingleAPITestDescriptorDocument.SuccessDocument(
                apiDescription: .none,
                body: .init(resourceObject: try descriptor.serializable().0),
                includes: .none,
                meta: .none,
                links: .none
            )
        }
        .flatMap(req.response.success.encode)
    }
}

extension APITestController {
    static func givenProperties(
        with testPropertiesId: API.APITestProperties.Id,
        on db: Database
    ) -> EventLoopFuture<(DB.APITestProperties, DB.OpenAPISource)> {
        return DB.APITestProperties
            .query(on: db)
            .filter(\.$id == testPropertiesId.rawValue)
            .with(\.$openAPISource)
            .first()
            .optionalMap { ($0, $0.$openAPISource.value!) }
            .unwrap(or: Abort(.badRequest, reason: "Given API test properties could not be found."))
    }

    func defaultProperties(on db: Database) -> EventLoopFuture<(DB.APITestProperties, DB.OpenAPISource)> {
        guard let defaultSource = defaultOpenAPISource else {
            return db.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "No API Test properties specified and no default OpenAPI Source available."))
        }

        let defaultSourceAndId = defaultSource
            .dbModel(from: db)
            .flatMapThrowing { source in
                (source, try source.requireID())
        }

        return defaultSourceAndId
            .flatMap { (source, sourceId) in
                DB.APITestProperties
                    .query(on: db)
                    .filter(\.$openAPISource.$id == sourceId)
                    .filter(\.$apiHostOverride == nil)
                    .first(orCreate: DB.APITestProperties(openAPISourceId: sourceId, apiHostOverride: nil))
                    .map { ($0, source) }
        }
    }
}

// MARK: - Route Contexts
extension APITestController {
    struct IndexContext: JSONAPIRouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let include: CSVQueryParam<String> = .init(
            name: "include",
            description: "Include the given types of resources in the response.",
            allowedValues: ["testProperties", "testProperties.openAPISource", "messages"]
        )

        let success: ResponseContext<API.BatchAPITestDescriptorDocument.SuccessDocument> = .init { response in
            response.status = .ok
            response.headers.contentType = .jsonAPI
        }

        static let shared = Self()
    }

    struct ShowContext: JSONAPIRouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let include: CSVQueryParam<String> = .init(
            name: "include",
            description: "Include the given types of resources in the response.",
            allowedValues: ["testProperties", "testProperties.openAPISource", "messages"]
        )

        let success: ResponseContext<API.SingleAPITestDescriptorDocument.SuccessDocument> = .init { response in
            response.status = .ok
            response.headers.contentType = .jsonAPI
        }

        let notFound: CannedResponse<API.SingleAPITestDescriptorDocument.ErrorDocument>
            = Controller.jsonNotFoundError(details: "The requested tests were not found")

        let badRequest: CannedResponse<API.SingleAPITestDescriptorDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "Test ID not specified in path")

        static let shared = Self()
    }

    struct FilesContext: RouteContext {
        typealias RequestBodyType = EmptyRequestBody

        static let defaultContentType: HTTPMediaType? = .zip

        let success: ResponseContext<ByteBuffer> = .init { response in
            response.status = .ok
            response.headers.contentType = .zip
        }

        let notFound: CannedResponse<EmptyResponseBody> = .init(
            response: Response(status: .notFound)
        )

        let badRequest: CannedResponse<EmptyResponseBody> = .init(
            response: Response(status: .badRequest)
        )

        static let shared = Self()
    }

    struct LogsContext: RouteContext {
        typealias RequestBodyType = EmptyRequestBody

        static let defaultContentType: HTTPMediaType? = .plainText

        let success: ResponseContext<ByteBuffer> = .init { response in
            response.status = .ok
            response.headers.contentType = .plainText
        }

        let notFound: CannedResponse<EmptyResponseBody> = .init(
                response: Response(status: .notFound)
        )

        let badRequest: CannedResponse<EmptyResponseBody> = .init(
            response: Response(status: .badRequest)
        )

        static let shared = Self()
    }

    struct CreateContext: JSONAPIRouteContext {
        typealias RequestBodyType = API.CreateAPITestDescriptorDocument

        let success: ResponseContext<API.SingleAPITestDescriptorDocument.SuccessDocument> = .init { response in
            response.status = .accepted
            response.headers.contentType = .jsonAPI
        }

        let noOpenAPIDocumentSpecified: CannedResponse<API.SingleAPITestDescriptorDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "No OpenAPI Document was specified.")

        let malformedRequestBody: CannedResponse<API.SingleAPITestDescriptorDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "The request body could not be parsed as a document with primary resource of type \(RequestBodyType.PrimaryResourceBody.PrimaryResource.jsonType)")

        static let shared = Self()
    }
}

// MARK: - Route Configuration
extension APITestController {
    public func mount(on app: Application, at rootPath: RoutingKit.PathComponent...) {
        app.on(.POST, rootPath, use: self.create)
            .tags("Testing")
            .summary("Run tests")
            .description("""
Running tests is an asynchronous operation. This route will return immediately if it was able to queue up a new test run.

You can monitor the status of your test run with the `GET` `/api_test/{id}` endpoint (the object returned has a `status` attribute).
"""
        )

        app.on(.GET, rootPath, use: self.index)
            .tags("Testing")
            .summary("Retrieve all test results")

        app.on(.GET, rootPath + [":id"], use: self.show)
            .tags("Testing")
            .summary("Retrieve a single test result")

        // MARK: File Retrieval
        app.on(.GET, rootPath + [":id", "files"], use: self.files)
            .tags("Test Files")
            .summary("Retrieve the test files for the given test run.")

        app.on(.GET, rootPath + [":id", "logs"], use: self.logs)
            .tags("Test Files")
            .summary("Retrieve the test logs for the given test run.")
    }
}
