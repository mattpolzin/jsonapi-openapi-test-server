import Vapor
import SwiftGen
import OpenAPIKit
import FluentPostgresDriver

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

    /// Returns a list of all `Todo`s.
//    func index(_ req: Request) throws -> Future<[Todo]> {
//        return Todo.query(on: req).all()
//    }

    func create(_ req: Request) throws -> EventLoopFuture<Response> {
        let reqUUIDGuess = req
            .logger[metadataKey: "uuid"]
            .map { $0.description }
            .flatMap(UUID.init(uuidString:))
        let descriptor = APITestDescriptor(id: reqUUIDGuess ?? UUID())

        let savedDescriptor = descriptor.save(on: database)

        savedDescriptor.whenSuccess { [weak self] in

            guard let source = self?.openAPISource,
                let database = self?.database,
                let outPath = self?.outputPath else { return }  // this just happens if the controller has been released from memory

            Self.prepOutputFolder(on: req.eventLoop, at: outPath)
                .flatMap { descriptor.markBuilding().save(on: database) }
                .transform(to: Self.openAPIDoc(on: req.eventLoop, from: source))
                .flatMap { openAPIDoc in Self.produceAPITestPackage(on: req.eventLoop, given: openAPIDoc, to: outPath) }
                .flatMap { descriptor.markRunning().save(on: database) }
                .transform(to: Self.runAPITestPackage(on: req.eventLoop, at: outPath))
                .flatMap { descriptor.markPassed().save(on: database) }
                .whenFailure { error in
                    req.logger.error("Failed to run tests",
                                     metadata: ["error": .stringConvertible(String(describing: error))])
                    let _ = descriptor.markFailed().save(on: database)
            }
        }

        return savedDescriptor.flatMap { descriptor.encodeResponse(status: .accepted, for: req) }
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
                                      to outputPath: String) -> EventLoopFuture<Void> {
        loop.submit { SwiftGen.produceAPITestPackage(from: openAPIDoc, outputTo: outputPath) }
    }

    static func runAPITestPackage(on loop: EventLoop,
                                  at outputPath: String) -> EventLoopFuture<Void> {
        loop.submit { try SwiftGen.runAPITestPackage(at: outputPath) }
    }
}
