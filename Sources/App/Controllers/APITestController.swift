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
        let shouldIncludeSource = req.query.include?
            .contains("openAPISource")
            ?? false

        return API.batchAPITestDescriptorResponse(
            query: DB.APITestDescriptor.query(on: req.db),
            includeSource: shouldIncludeSource,
            includeMessages: shouldIncludeMessages
        )
        .flatMap(req.response.success.encode)
        .flatMapError { _ in req.response.serverError }
    }

    func show(_ req: TypedRequest<ShowContext>) throws -> EventLoopFuture<Response> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            return req.response.badRequest
        }

        let query = DB.APITestDescriptor.query(on: req.db)
            .filter(\.$id == id)

        let shouldIncludeMessages = req.query.include?
            .contains("messages")
            ?? false
        let shouldIncludeSource = req.query.include?
            .contains("openAPISource")
            ?? false

        return API.singleAPITestDescriptorResponse(
            query: query,
            includeSource: shouldIncludeSource,
            includeMessages: shouldIncludeMessages
        )
        .flatMap(req.response.success.encode)
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

        let query = DB.APITestDescriptor.query(on: req.db)
            .filter(\.$id == id)

        return query.first()
            .unwrap(or: Abort(.notFound))
            .map(self.zipPath)
            .flatMap(req.fileio.collectFile)
            .flatMap(req.response.success.encode)
            .flatMapError { error in
                guard let abortError = error as? Abort,
                    abortError.status == .notFound else {
                        return req.response.serverError
                }
                return req.response.notFound
        }
    }

    /// Create an `APITestDescriptor` and run new tests.
    func create(_ req: TypedRequest<CreateContext>) throws -> EventLoopFuture<Response> {
        let reqUUIDGuess = req
            .logger[metadataKey: "uuid"]
            .map { $0.description }
            .flatMap(UUID.init(uuidString:))

        let requestedOpenAPISource = req.eventLoop.makeSucceededFuture(())
            .flatMapThrowing { try req.decodeBody().body.primaryResource?.value }
            .optionalMap { $0 ~> \.openAPISource }
            .flatMap { DB.OpenAPISource.find($0, on: req.db) }

        let futureOpenAPISource: EventLoopFuture<DB.OpenAPISource> = requestedOpenAPISource
            .flatMap {
                if let source = $0 {
                    return req.eventLoop.makeSucceededFuture(source)
                }

                guard let defaultSource = self.defaultOpenAPISource else {
                    return req.eventLoop.makeFailedFuture(Abort(.badRequest))
                }

                return defaultSource
                    .dbModel(from: req.db)
        }

        let descriptorFuture = futureOpenAPISource.flatMapThrowing { sourceModel in
            (
                try DB.APITestDescriptor(
                    id: reqUUIDGuess ?? UUID(),
                    openAPISource: sourceModel
                ),
                sourceModel
            )
        }

        let savedDescriptorTuple = descriptorFuture
            .flatMap { $0.0.save(on: req.db) }
            .flatMap { descriptorFuture }

        // Kick tests off asynchronously
        savedDescriptorTuple.whenSuccess { [weak self] (descriptor, source) in

            // this just fails if the controller has been released from memory
            // which we consider possible here because this whole process is async
            // and independent of the API request completion.
            guard let self = self else { return }

            let outPath = self.outPath(for: descriptor)
            let zipPath = self.zipPath(for: descriptor)
            let eventLoop = self.testEventLoop()

            let testLogger = Controller.Logger(
                systemLogger: req.logger,
                descriptor: descriptor,
                eventLoop: eventLoop,
                database: req.db
            )

            let _ = APITestCommand.kickTestsOff(
                testProgressTracking: (descriptor, req.db),
                source: .init(source),
                outPath: outPath,
                zipPath: zipPath,
                eventLoop: eventLoop,
                requestLogger: req.logger,
                testLogger: testLogger
            )
        }

        return savedDescriptorTuple.flatMapThrowing { (descriptor, _) in
            API.SingleAPITestDescriptorDocument.SuccessDocument(
                apiDescription: .none,
                body: .init(resourceObject: try descriptor.serializable().0),
                includes: .none,
                meta: .none,
                links: .none
            )
        }
        .flatMap(req.response.success.encode)
        .flatMapError { err in
            switch err {
            case is DecodingError,
                 is JSONAPI.DocumentDecodingError:
                return req.response.malformedRequestBody

            case let error as AbortError:
                switch error.status {
                case .badRequest:
                    return req.response.noOpenAPIDocumentSpecified
                case .unprocessableEntity:
                    return req.response.malformedRequestBody
                default:
                    return req.response.serverError
                }

            default:
                return req.response.serverError
            }
        }
    }
}

// MARK: - Route Contexts
extension APITestController {
    struct IndexContext: RouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let include: CSVQueryParam<String> = .init(
            name: "include",
            description: "Include the given types of resources in the response.",
            allowedValues: ["openAPISource", "messages"]
        )

        let success: ResponseContext<API.BatchAPITestDescriptorDocument.SuccessDocument> =
            .init { response in
                response.status = .ok
        }

        let serverError: CannedResponse<API.BatchAPITestDescriptorDocument.ErrorDocument>
            = Controller.jsonServerError()

        static let shared = Self()
    }

    struct ShowContext: RouteContext {
        typealias RequestBodyType = EmptyRequestBody

        let include: CSVQueryParam<String> = .init(
            name: "include",
            description: "Include the given types of resources in the response.",
            allowedValues: ["openAPISource", "messages"]
        )

        let success: ResponseContext<API.SingleAPITestDescriptorDocument.SuccessDocument> =
            .init { response in
                response.status = .ok
        }

        let notFound: CannedResponse<API.SingleAPITestDescriptorDocument.ErrorDocument>
            = Controller.jsonNotFoundError(details: "The requested tests were not found")

        let badRequest: CannedResponse<API.SingleAPITestDescriptorDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "Test ID not specified in path")

        let serverError: CannedResponse<API.SingleAPITestDescriptorDocument.ErrorDocument>
            = Controller.jsonServerError()

        static let shared = Self()
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

        static let shared = Self()
    }

    struct CreateContext: RouteContext {
        typealias RequestBodyType = API.NewAPITestDescriptorDocument

        let success: ResponseContext<API.SingleAPITestDescriptorDocument.SuccessDocument> =
            .init { response in
                response.status = .accepted
        }

        let noOpenAPIDocumentSpecified: CannedResponse<API.SingleAPITestDescriptorDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "No OpenAPI Document was specified.")

        let malformedRequestBody: CannedResponse<API.SingleAPITestDescriptorDocument.ErrorDocument>
            = Controller.jsonBadRequestError(details: "The request body could not be parsed as an \(RequestBodyType.PrimaryResourceBody.PrimaryResource.jsonType)")

        let serverError: CannedResponse<API.SingleAPITestDescriptorDocument.ErrorDocument>
            = Controller.jsonServerError()

        static let shared = Self()
    }
}
