import Vapor
import SwiftGen
import OpenAPIKit
import FluentPostgresDriver
import struct Logging.Logger
import JSONAPI
import APITesting

/// Controls basic CRUD operations on `Todo`s.
final class APITestController {

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
    func index(_ req: Request) throws -> EventLoopFuture<API.BatchAPITestDescriptorResponse> {
        // TODO: only include if requested
        return API.batchAPITestDescriptorResponse(query: APITestDescriptor.query(on: database),
                                                  includeMessages: true)
    }

    func show(_ req: Request) throws -> EventLoopFuture<API.SingleAPITestDescriptorResponse> {
        let id = req.parameters.get("id", as: UUID.self)

        // ideally this would be APITestDescriptor.find() but that does
        // not currently allow eager loading of relatives. It also would
        // be nice if filtering by ID were supported more directly, but
        // at the moment the best support is just for filtering Fields.
        let query = APITestDescriptor.query(on: database)
            .filter(DatabaseQuery.Filter.basic(.field(path: ["id"], schema: nil, alias: nil), .equal, .bind(id)))

        return API.singleAPITestDescriptorResponse(query: query,
                                                   includeMessages: true)
    }

    private func testEventLoop() -> EventLoop {
        return testEventLoopGroup.next()
    }

    /// Create an `APITestDescriptor` and run a new test suite.
    func create(_ req: Request) throws -> EventLoopFuture<Response> {
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

            guard let source = self?.openAPISource,
                let database = self?.database,
                let outPath = self?.outputPath,
                let eventLoop = self?.testEventLoop() else { return }  // this just happens if the controller has been released from memory

            prepOutputFolder(on: eventLoop, at: outPath, logger: logger)
                .flatMap { descriptor.markBuilding().save(on: database) }
                .flatMap { openAPIDoc(on: eventLoop, from: source) }
                .flatMap { openAPIDoc in produceAPITestPackage(on: eventLoop, given: openAPIDoc, to: outPath, logger: logger) }
                .flatMap { descriptor.markRunning().save(on: database) }
                .flatMap { runAPITestPackage(on: eventLoop, at: outPath, logger: logger) }
                .flatMap { descriptor.markPassed().save(on: database) }
                .whenFailure { error in
                    req.logger.error("Failed to run tests",
                                     metadata: ["error": .stringConvertible(String(describing: error))])
                    // following is tmp to workaround above metadata not being dumped to console with previous call:
                    req.logger.error("\(String(describing: error))")
                    let _ = descriptor.markFailed().save(on: database)
            }
        }

        return savedDescriptor.flatMapThrowing { _ in
            API.SingleAPITestDescriptorResponse(
                API.SingleDocument<API.APITestDescriptor, NoIncludes>(apiDescription: .none,
                                                                      body: .init(resourceObject: try descriptor.serializable().0),
                                                                      includes: .none,
                                                                      meta: .none,
                                                                      links: .none)
            )
        }.flatMap { $0.encodeResponse(status: .accepted, for: req) }
    }

    /// Deletes a parameterized `Todo`.
//    func delete(_ req: Request) throws -> Future<HTTPStatus> {
//        return try req.parameters.next(Todo.self).flatMap { todo in
//            return todo.delete(on: req)
//        }.transform(to: .ok)
//    }
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
    }
}
