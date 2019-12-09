//
//  APITestCommand.swift
//  App
//
//  Created by Mathew Polzin on 9/28/19.
//

import Foundation
import Vapor
import SwiftGen
import OpenAPIKit

public final class APITestCommand: Command {
    public struct Signature: CommandSignature {

        @Flag(
            name: "dump-files",
            help: "Dump produced test files in a zipped file at the current working directory."
        )
        var dumpFiles: Bool

        public init() {}
    }

    public let signature = Signature()

    public let help = "Run API Tests."

    let testEventLoopGroup: MultiThreadedEventLoopGroup
    let outPath: String
    let openAPISource: OpenAPISource

    public init() throws {
        self.testEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.outPath = Environment.outPath
        self.openAPISource = try .detect()
    }

    deinit {
        try! testEventLoopGroup.syncShutdownGracefully()
    }

    private func testEventLoop() -> EventLoop {
        return testEventLoopGroup.next()
    }

    public func run(using context: CommandContext, signature: APITestCommand.Signature) throws {
        let logger = Logger(console: context.console)

        let eventLoop = testEventLoop()
        let source = openAPISource
        let path = outPath

        context.console.print()

        let cwd = FileManager.default.currentDirectoryPath

        let zipToArg = signature.dumpFiles ? cwd + "/api_test_files.zip" : nil

        try Self.kickTestsOff(
            source: source,
            outPath: path,
            zipPath: zipToArg,
            eventLoop: eventLoop,
            testLogger: logger
        )
        .wait()
    }

    public static func kickTestsOff(
        source: OpenAPISource,
        outPath: String,
        zipPath: String?,
        eventLoop: EventLoop,
        testLogger: SwiftGen.Logger
    ) -> EventLoopFuture<Void> {
        return Self.kickTestsOff(
            testProgressTracking: nil as (NullTracker, Never)?,
            source: source,
            outPath: outPath,
            zipPath: zipPath,
            eventLoop: eventLoop,
            requestLogger: nil,
            testLogger: testLogger
        )
    }

    /// Kick off API Tests
    ///
    /// - parameters:
    ///     - testProgressTracking: (Optional) If specified, tuple with both
    ///         a progress tracker and a persistence layer delegate. This is not required
    ///         to run tests.
    ///     - source: The source of the OpenAPI documentation for which to generate tests.
    ///     - outPath: The local path at which test files should be stored.
    ///     - zipPath: (Optional) If specified, test files will be zipped and saved to a file at this path.
    ///     - eventLoop: The event loop on which the tests should be executed.
    ///     - requestLogger: (Optional) If specified, a system logger to which certain process related
    ///         status updates will be logged. These updates will not be the results of tests with the
    ///         notable exception of test summaries on failure (although if this logger is `nil`,
    ///         the test summary will be logged to the testLogger).
    ///     - testLogger: A logger to which test-related log messages will be recorded.
    public static func kickTestsOff<Persister, Tracker: TestProgressTracker>(
        testProgressTracking: (Tracker, Persister)?,
        source: OpenAPISource,
        outPath: String,
        zipPath: String?,
        eventLoop: EventLoop,
        requestLogger: Logging.Logger?,
        testLogger: SwiftGen.Logger
    ) -> EventLoopFuture<Void> where Tracker.Persister == Persister {
        requestLogger?.info("Running tests in \(outPath)")

        let testProgressTracker = testProgressTracking?.0

        func trackProgress(_ progress: @autoclosure () -> Tracker?) -> EventLoopFuture<Void> {
            zip(progress(), testProgressTracking?.1)
                .map { $0.0.save(on: $0.1) }
                ?? eventLoop.makeSucceededFuture(())
        }

        return prepOutputFolder(
            on: eventLoop,
            at: outPath,
            logger: testLogger
        )
        .flatMap { trackProgress(testProgressTracker?.markBuilding()) }
        .flatMap { openAPIDoc(on: eventLoop, from: source) }
        .flatMap { openAPIDoc in
            produceAPITestPackage(
                on: eventLoop,
                given: openAPIDoc,
                to: outPath,
                zipToPath: zipPath,
                logger: testLogger
            )
        }
        .flatMap { trackProgress(testProgressTracker?.markRunning()) }
        .flatMap { runAPITestPackage(
            on: eventLoop,
            at: outPath,
            logger: testLogger
            )
        }
        .flatMap { trackProgress(testProgressTracker?.markPassed()) }
        .always { _ in
            try? cleanupOutFolder(outPath, logger: testLogger)
            requestLogger?.info("Cleaning up tests in \(outPath)")
        }
        .recover { error in
            // For requests with the ability to distinguish between request
            // logging and test logging, only log this "summary" message
            // to the request logger. For any other request, log it to the
            // test logger.
            if let requestLogger = requestLogger {
                requestLogger.error("Testing Failed",
                                     metadata: ["error": .stringConvertible(String(describing: error))])
                // following is tmp to workaround above metadata not being dumped to console with previous call:
                requestLogger.error("\(String(describing: error))")
            } else {
                testLogger.error(path: nil,
                                 context: "Testing Failed",
                                 message: String(describing: error))
            }

            let _ = trackProgress(testProgressTracker?.markFailed())
        }
    }
}

// MARK: - Logger
extension APITestCommand {
    final class Logger: SwiftGen.Logger {
        let console: Console

        init(console: Console) {
            self.console = console
        }

        public func error(path: String?, context: String, message: String) {
            console.error("-> \(message)")
            console.print("--")
            console.print("-- \(context)")
            if let path = path {
                console.print("-- at [", newLine: false)
                console.error(path, newLine:  false)
                console.print("]")
            }
            console.print()
            console.print()
        }

        public func warning(path: String?, context: String, message: String) {
            console.warning("-> \(message)")
            console.print("--")
            console.print("-- \(context)")
            if let path = path {
                console.print("-- at [", newLine: false)
                console.warning(path, newLine:  false)
                console.print("]")
            }
            console.print()
            console.print()
        }

        public func success(path: String?, context: String, message: String) {
            console.success("-> \(message)")
            console.print("--")
            console.print("-- \(context)")
            if let path = path {
                console.print("-- at [", newLine: false)
                console.success(path, newLine:  false)
                console.print("]")
            }
            console.print()
            console.print()
        }
    }
}

// MARK: - Helpers
public func prepOutputFolder(on loop: EventLoop,
                             at outputPath: String,
                             logger: SwiftGen.Logger) -> EventLoopFuture<Void> {

    loop.submit { try prepOutFolder(outputPath, logger: logger) }
}

public func openAPIDoc(on loop: EventLoop,
                       from source: OpenAPISource) -> EventLoopFuture<OpenAPI.Document> {
    /// Get the OpenAPI documentation from a URL
    func get(_ url: URI, credentials: (username: String, password: String)? = nil) -> EventLoopFuture<OpenAPI.Document> {
        let client = HTTPClient(eventLoopGroupProvider: .shared(loop))

        var headers = HTTPHeaders()
        if let (username, password) = credentials {
            headers.add(name: .authorization, value: HTTPClient.Authorization.basic(username: username, password: password).headerValue)
        }

        let request: HTTPClient.Request
        do {
            request = try HTTPClient.Request(url: url.string,
                                         method: .GET,
                                         headers: headers)
        } catch {
            return loop.makeFailedFuture(Abort(.badRequest))
        }

        return client.execute(request: request).flatMapThrowing { response in
            try client.syncShutdown()
            return try ClientResponse(status: response.status, headers: response.headers, body: response.body)
                .content.decode(OpenAPI.Document.self)
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

public func produceAPITestPackage(on loop: EventLoop,
                                  given openAPIDoc: OpenAPI.Document,
                                  to outputPath: String,
                                  zipToPath: String? = nil,
                                  logger: SwiftGen.Logger) -> EventLoopFuture<Void> {
    loop.submit {
        SwiftGen.produceAPITestPackage(
            from: openAPIDoc,
            outputTo: outputPath,
            zipToPath: zipToPath,
            logger: logger
        )
    }
}

public func runAPITestPackage(on loop: EventLoop,
                              at outputPath: String,
                              logger: SwiftGen.Logger) -> EventLoopFuture<Void> {
    loop.submit {
        try SwiftGen.runAPITestPackage(
            at: outputPath,
            logger: logger
        )
    }
}

public enum OpenAPISource {
    case file(path: String)
    case unauthenticated(url: URI)
    case basicAuth(url: URI, username: String, password: String)

    public enum Error: Swift.Error {
        case noInputSpecified
        case fileReadError(String)
    }
}
