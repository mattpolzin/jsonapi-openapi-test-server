import Vapor
import SwiftGen
import OpenAPIKit
import FluentPostgresDriver
import struct Logging.Logger
import JSONAPI

/// Controls basic CRUD operations on `Todo`s.
final class APITestController {

    let outputPath: String
    let openAPISource: OpenAPISource
    let database: Database

    init(outputPath: String,
         openAPISource: OpenAPISource,
         database: Database) {
        self.outputPath = outputPath
        self.openAPISource = openAPISource
        self.database = database
    }

    /// Returns a list of all `APITestDescriptor`s.
    func index(_ req: Request) throws -> EventLoopFuture<API.BatchAPITestDescriptorResponse> {
        // TODO: only include if requested
        return API.batchAPITestDescriptorResponse(query: APITestDescriptor.query(on: database), includeMessages: true)
    }

//    func show(_ req: Request) throws -> EventLoopFuture<APITestDescriptor> {
//
//    }

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
                let outPath = self?.outputPath else { return }  // this just happens if the controller has been released from memory

            Self.prepOutputFolder(on: req.eventLoop, at: outPath)
                .flatMap { descriptor.markBuilding().save(on: database) }
                .flatMap { Self.openAPIDoc(on: req.eventLoop, from: source) }
                .flatMap { openAPIDoc in Self.produceAPITestPackage(on: req.eventLoop, given: openAPIDoc, to: outPath, logger: logger) }
                .flatMap { descriptor.markRunning().save(on: database) }
                .flatMap { Self.runAPITestPackage(on: req.eventLoop, at: outPath, logger: logger) }
                .flatMap { descriptor.markPassed().save(on: database) }
                .whenFailure { error in
                    req.logger.error("Failed to run tests",
                                     metadata: ["error": .stringConvertible(String(describing: error))])
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
    enum OpenAPISource {
        case file(path: String)
        case unauthenticated(url: URI)
        case basicAuth(url: URI, username: String, password: String)

        static func detect() throws -> OpenAPISource {
            if let path = Environment.inFile {
                return .file(path: path)
            }

            if let url = Environment.inUrl.map(URI.init(string:)) {

                if let (username, password) = try Environment.credentials() {
                    return .basicAuth(url: url, username: username, password: password)
                }

                return .unauthenticated(url: url)
            }

            throw Error.noInputSpecified
        }

        public enum Error: Swift.Error {
            case noInputSpecified
            case fileReadError(String)
        }
    }
}

extension APITestController {
    static func prepOutputFolder(on loop: EventLoop,
                                 at outputPath: String) -> EventLoopFuture<Void> {

        loop.submit { prepOutFolder(outputPath) }
    }

    static func openAPIDoc(on loop: EventLoop,
                           from source: OpenAPISource) -> EventLoopFuture<OpenAPI.Document> {
        /// Get the OpenAPI documentation from a URL
        func get(_ url: URI, credentials: (username: String, password: String)? = nil) -> EventLoopFuture<OpenAPI.Document> {
            let client = HTTPClient(eventLoopGroupProvider: .shared(loop))

            var headers = HTTPHeaders()
            if let (username, password) = credentials {
                headers.add(name: .authorization, value: HTTPClient.Authorization.basic(username: username, password: password).headerValue)
            }

            return client.get(url, headers: headers).flatMapThrowing {
                try client.syncShutdown()
                return try $0.content.decode(OpenAPI.Document.self)
            }
        }

        switch source {
        case .file(path: let path):
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                let decoder = JSONDecoder()

                return try loop.makeSucceededFuture(decoder.decode(OpenAPI.Document.self, from: data))
            } catch let error {
                return loop.makeFailedFuture(OpenAPISource.Error.fileReadError(String(describing: error)))
            }

        case .basicAuth(url: let url,
                        username: let username,
                        password: let password):

            return get(url, credentials: (username: username, password: password))

        case .unauthenticated(url: let url):
            return get(url)
        }
    }

    static func produceAPITestPackage(on loop: EventLoop,
                                      given openAPIDoc: OpenAPI.Document,
                                      to outputPath: String,
                                      logger: Logger) -> EventLoopFuture<Void> {
        loop.submit { SwiftGen.produceAPITestPackage(from: openAPIDoc, outputTo: outputPath, logger: logger) }
    }

    static func runAPITestPackage(on loop: EventLoop,
                                  at outputPath: String,
                                  logger: Logger) -> EventLoopFuture<Void> {
        loop.submit { try SwiftGen.runAPITestPackage(at: outputPath, logger: logger) }
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

        public func error(context: String, message: String) {
            systemLogger.error("\(message)", metadata: ["context": .string(context)])
            let _ = eventLoop.submit { try APITestMessage(testDescriptor: self.descriptor,
                                              messageType: .error,
                                              context: context.isEmpty ? nil : context,
                                              message: message).save(on: self.database) }
        }

        public func warning(context: String, message: String) {
            systemLogger.warning("\(message)", metadata: ["context": .string(context)])
            let _ = eventLoop.submit { try APITestMessage(testDescriptor: self.descriptor,
                                                      messageType: .warning,
                                                      context: context.isEmpty ? nil : context,
                                                      message: message).save(on: self.database) }
        }
    }
}
