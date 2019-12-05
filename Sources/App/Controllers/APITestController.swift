import Vapor
import SwiftGen
import OpenAPIKit
import FluentPostgresDriver
import struct Logging.Logger
import JSONAPI
import APITesting

/// Controls basic CRUD operations on `Todo`s.
final class APITestController {

    static let zipPathPrefix = Environment.archivesPath
    let outputPath: String
    let openAPISource: OpenAPISource
    let database: Database
    let testEventLoopGroup: MultiThreadedEventLoopGroup

    init(outputPath: String,
         openAPISource: OpenAPISource,
         database: Database) {
        self.outputPath = outputPath
        self.openAPISource = openAPISource
        self.database = database
        self.testEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    deinit {
        try! testEventLoopGroup.syncShutdownGracefully()
    }

    /// Returns a list of all `APITestDescriptor`s.
    func index(_ req: TypedRequest<IndexContext>) throws -> EventLoopFuture<Response> {
        // TODO: only include if requested
        return API.batchAPITestDescriptorResponse(query: APITestDescriptor.query(on: database),
                                                  includeMessages: true)
            .flatMap { req.response.success.encode($0) }
            .flatMapError { _ in req.response.serverError }
    }

    func show(_ req: TypedRequest<ShowContext>) throws -> EventLoopFuture<Response> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            return req.response.badRequest
        }

        let query = APITestDescriptor.query(on: database)
            .filter(\APITestDescriptor.$id == id)

        return API.singleAPITestDescriptorResponse(query: query, includeMessages: true)
            .flatMap { req.response.success.encode($0) }
            .flatMapError { error in
                guard let abortError = error as? Abort,
                    abortError.status == .notFound else {
                        return req.response.serverError
                }
                return req.response.notFound
        }
    }

    func files(_ req: TypedRequest<FilesContext>) throws -> EventLoopFuture<Response> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            return req.response.badRequest
        }

        let query = APITestDescriptor.query(on: database)
            .filter(\APITestDescriptor.$id == id)

        return query.first()
            .unwrap(or: Abort(.notFound))
            .flatMap { req.fileio.collectFile(at: self.zipPath(for: $0)) }
            .flatMap { req.response.success.encode($0) }
            .flatMapError { error in
                guard let abortError = error as? Abort,
                    abortError.status == .notFound else {
                        return req.response.serverError
                }
                return req.response.notFound
        }
    }

    /// Create an `APITestDescriptor` and run a new test suite.
    func create(_ req: TypedRequest<CreateContext>) throws -> EventLoopFuture<Response> {
        let reqUUIDGuess = req
            .logger[metadataKey: "uuid"]
            .map { $0.description }
            .flatMap(UUID.init(uuidString:))
        let descriptor = APITestDescriptor(id: reqUUIDGuess ?? UUID())

        let logger = Logger(systemLogger: req.logger,
                            descriptor: descriptor,
                            eventLoop: req.eventLoop,
                            database: database)

        let savedDescriptor = descriptor.save(on: database)

        savedDescriptor.whenSuccess { [weak self] in

            // this just happens if the controller has been released from memory
            // which we consider possible here because this whole process is async
            // and independent of the API request completion.
            guard let self = self else { return }

            let source = self.openAPISource
            let database = self.database
            let outPath = self.outPath(for: descriptor)
            let zipPath = self.zipPath(for: descriptor)
            let eventLoop = self.testEventLoop()

            req.logger.info("Running tests in \(outPath)")

            prepOutputFolder(on: eventLoop, at: outPath, logger: logger)
                .flatMap { descriptor.markBuilding().save(on: database) }
                .flatMap { openAPIDoc(on: eventLoop, from: source) }
                .flatMap { openAPIDoc in produceAPITestPackage(on: eventLoop, given: openAPIDoc, to: outPath, zipToPath: zipPath, logger: logger) }
                .flatMap { descriptor.markRunning().save(on: database) }
                .flatMap { runAPITestPackage(on: eventLoop, at: outPath, logger: logger) }
                .flatMap { descriptor.markPassed().save(on: database) }
                .always { _ in
                    try? cleanupOutFolder(outPath, logger: logger)
                    req.logger.info("Cleaning up tests in \(outPath)")
                }
                .whenFailure { error in
                    req.logger.error("Testing Failed",
                                     metadata: ["error": .stringConvertible(String(describing: error))])
                    // following is tmp to workaround above metadata not being dumped to console with previous call:
                    req.logger.error("\(String(describing: error))")
                    let _ = descriptor.markFailed().save(on: database)
            }
        }

        return savedDescriptor.flatMapThrowing { _ in
            API.SingleAPITestDescriptorResponse.SuccessDocument(apiDescription: .none,
                                                                body: .init(resourceObject: try descriptor.serializable().0),
                                                                includes: .none,
                                                                meta: .none,
                                                                links: .none)
        }
        .flatMap { req.response.success.encode($0) }
        .flatMapError { _ in
            return req.response.serverError
        }
    }

    private func testEventLoop() -> EventLoop {
        return testEventLoopGroup.next()
    }

    private func zipPath(for test: APITestDescriptor) -> String {
        return Self.zipPathPrefix
            + "/\(test.id!.uuidString).zip"
    }

    private func outPath(for test: APITestDescriptor) -> String {
        return self.outputPath
            + "/\(test.id!.uuidString)/"
    }

    // MARK: - Contexts

    struct CreateContext: RouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let success: ResponseContext<API.SingleAPITestDescriptorResponse.SuccessDocument> =
            .init { response in
                response.status = .accepted
        }

        let serverError: CannedResponse<API.SingleAPITestDescriptorResponse.ErrorDocument> =
            .init(response: Response(
                status: .internalServerError,
                body: .init(data: try! JSONEncoder().encode(
                    API.SingleAPITestDescriptorResponse.ErrorDocument(
                        apiDescription: .none,
                        errors: [
                            .error(.init(id: nil, title: "Internal Server Error", detail: "Unknown error occurred"))
                        ]
                    )
                ))
            )
        )

        static let builder = { return Self() }
    }

    struct IndexContext: RouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let success: ResponseContext<API.BatchAPITestDescriptorResponse.SuccessDocument> =
            .init { response in
                response.status = .ok
        }

        let serverError: CannedResponse<API.BatchAPITestDescriptorResponse.ErrorDocument> =
            .init(response: Response(
                status: .internalServerError,
                body: .init(data: try! JSONEncoder().encode(
                    API.BatchAPITestDescriptorResponse.ErrorDocument(
                        apiDescription: .none,
                        errors: [
                            .error(.init(id: nil, title: "Internal Server Error", detail: "Unknown error occurred"))
                        ]
                    )
                    ))
                )
        )

        static let builder = { return Self() }
    }

    struct ShowContext: RouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let success: ResponseContext<API.SingleAPITestDescriptorResponse.SuccessDocument> =
            .init { response in
                response.status = .ok
        }

        let notFound: CannedResponse<API.SingleAPITestDescriptorResponse.ErrorDocument> =
            .init(response: Response(
                status: .notFound,
                body: .init(data: try! JSONEncoder().encode(
                    API.SingleAPITestDescriptorResponse.ErrorDocument(
                        apiDescription: .none,
                        errors: [
                            .error(.init(id: nil, title: "Not Found", detail: "The requested tests were not found"))
                        ]
                    )
                ))
            )
        )

        let badRequest: CannedResponse<API.SingleAPITestDescriptorResponse.ErrorDocument> =
            .init(response: Response(
                status: .badRequest,
                body: .init(data: try! JSONEncoder().encode(
                    API.SingleAPITestDescriptorResponse.ErrorDocument(
                        apiDescription: .none,
                        errors: [
                            .error(.init(id: nil, title: "Bad Request", detail: "Test ID not specified in path"))
                        ]
                    )
                ))
            )
        )

        let serverError: CannedResponse<API.SingleAPITestDescriptorResponse.ErrorDocument> =
            .init(response: Response(
                status: .internalServerError,
                body: .init(data: try! JSONEncoder().encode(
                    API.SingleAPITestDescriptorResponse.ErrorDocument(
                        apiDescription: .none,
                        errors: [
                            .error(.init(id: nil, title: "Internal Server Error", detail: "Unknown error occurred"))
                        ]
                    )
                ))
            )
        )

        static let builder = { return Self() }
    }

    struct FilesContext: RouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let success: ResponseContext<ByteBuffer> =
            .init { response in
                response.status = .ok
                response.headers.contentType = .zip
        }

        let notFound: CannedResponse<EmptyResponseBody> =
            .init(response: Response(
                status: .notFound
            )
        )

        let badRequest: CannedResponse<EmptyResponseBody> =
            .init(response: Response(
                status: .badRequest
            )
        )

        let serverError: CannedResponse<EmptyResponseBody> =
            .init(response: Response(
                status: .internalServerError
            )
        )

        static let builder = { return Self() }
    }
}

extension APITestController {
    final class Logger: SwiftGen.Logger {
        let systemLogger: Logging.Logger
        let descriptor: APITestDescriptor
        let eventLoop: EventLoop
        let database: Database

        init(systemLogger: Logging.Logger,
             descriptor: APITestDescriptor,
             eventLoop: EventLoop,
             database: Database) {
            self.systemLogger = systemLogger
            self.descriptor = descriptor
            self.eventLoop = eventLoop
            self.database = database
        }

        public func error(path: String?, context: String, message: String) {
            systemLogger.error("\(message)", metadata: ["context": .string(context)])
            let _ = eventLoop.submit { try APITestMessage(testDescriptor: self.descriptor,
                                                          messageType: .error,
                                                          path: path,
                                                          context: context.isEmpty ? nil : context,
                                                          message: message).save(on: self.database) }
        }

        public func warning(path: String?, context: String, message: String) {
            systemLogger.warning("\(message)", metadata: ["context": .string(context)])
            let _ = eventLoop.submit { try APITestMessage(testDescriptor: self.descriptor,
                                                          messageType: .warning,
                                                          path: path,
                                                          context: context.isEmpty ? nil : context,
                                                          message: message).save(on: self.database) }
        }

        public func success(path: String?, context: String, message: String) {
            systemLogger.info("\(message)", metadata: ["context": .string(context)])
            let _ = eventLoop.submit { try APITestMessage(testDescriptor: self.descriptor,
                                                          messageType: .success,
                                                          path: path,
                                                          context: context.isEmpty ? nil : context,
                                                          message: message).save(on: self.database) }
        }
    }
}
