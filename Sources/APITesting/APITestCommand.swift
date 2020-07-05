//
//  APITestCommand.swift
//  App
//
//  Created by Mathew Polzin on 9/28/19.
//

import Foundation
import Yams
import Vapor
import SwiftGen
import OpenAPIKit
import JSONAPISwiftGen

public final class APITestCommand: Command {
    public struct Signature: CommandSignature {

        @Flag(
            name: "dump-files",
            help: "Dump produced test files in a zipped file at the current working directory."
        )
        var shouldDumpFiles: Bool

        @Flag(
            name: "fail-hard",
            short: "f",
            help: "Produce a non-zero exit code if any tests fail."
        )
        var shouldFailHard: Bool

        @Flag(
            name: "ignore-warnings",
            help: "Do not print warnings in the output."
        )
        var shouldIgnoreWarnings: Bool

        @Option(
            name: "override-server",
            help: "Override the server definition(s) in the OpenAPI document for the purposes of this test run."
        )
        var serverOverride: URLOption?

        @Option(
            name: "openapi-file",
            help: "Specify a filename from the local filesystem from which to read OpenAPI documentation.",
            completion: .files(withExtensions: ["json", "yml", "yaml"])
        )
        var openAPIFile: String?

        public init() {}
    }

    public let signature = Signature()

    public let help = "Run API Tests."

    let testEventLoopGroup: MultiThreadedEventLoopGroup
    let outPath: String

    public init() throws {
        self.testEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.outPath = Environment.outPath
    }

    deinit {
        try! testEventLoopGroup.syncShutdownGracefully()
    }

    private func testEventLoop() -> EventLoop {
        return testEventLoopGroup.next()
    }

    public func run(using context: CommandContext, signature: APITestCommand.Signature) throws {
        let logger = Logger(console: context.console, enableWarnings: !signature.shouldIgnoreWarnings)

        let eventLoop = testEventLoop()
        let source: OpenAPISource = try signature.openAPIFile.map { .file(path: $0) } ?? .detect()
        let path = outPath

        let testProperties = APITestProperties(
            openAPISource: source,
            apiHostOverride: signature.serverOverride?.value
        )

        context.console.print()

        let cwd = FileManager.default.currentDirectoryPath

        let zipToArg = signature.shouldDumpFiles ? cwd + "/out/api_test_files.zip" : nil
        let testLogPath = cwd + "/out/api_test.log"

        let future = Self.kickTestsOff(
            testProperties: testProperties,
            outPath: path,
            zipPath: zipToArg,
            testLogPath: testLogPath,
            eventLoop: eventLoop,
            threadPool: .init(numberOfThreads: 1),
            testLogger: logger
        ).recover { _ in
            if signature.shouldFailHard {
                exit(1)
            }
        }

        try future
        .wait()
    }

    /// Kick off API Tests.
    ///
    /// - returns: An `EventLoopFuture` that will have failed if any tests have failed.
    public static func kickTestsOff(
        testProperties: APITestProperties,
        outPath: String,
        zipPath: String?,
        testLogPath: String,
        eventLoop: EventLoop,
        threadPool: NIOThreadPool,
        testLogger: SwiftGen.Logger
    ) -> EventLoopFuture<Void> {
        return Self.kickTestsOff(
            testProgressTracking: nil as (NullTracker, () -> Never)?,
            testProperties: testProperties,
            outPath: outPath,
            zipPath: zipPath,
            testLogPath: testLogPath,
            eventLoop: eventLoop,
            threadPool: threadPool,
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
    ///     - testSuiteConfiguration: The configuration for the whole test suite, including the OpenAPI documentation source.
    ///     - outPath: The local path at which test files should be stored.
    ///     - zipPath: (Optional) If specified, test files will be zipped and saved to a file at this path.
    ///     - testLogPath: The path and filename where plaintext test logs will be saved.
    ///     - eventLoop: The event loop on which the tests should be executed.
    ///     - threadPool: A thread pool that can be used to perform blocking work.
    ///     - requestLogger: (Optional) If specified, a system logger to which certain process related
    ///         status updates will be logged. These updates will not be the results of tests with the
    ///         notable exception of test summaries on failure (although if this logger is `nil`,
    ///         the test summary will be logged to the testLogger).
    ///     - testLogger: A logger to which test-related log messages will be recorded.
    ///
    /// - returns: An `EventLoopFuture` that will have failed if any tests have failed.
    public static func kickTestsOff<Persister, Tracker: TestProgressTracker>(
        testProgressTracking: (Tracker, () -> Persister)?,
        testProperties: APITestProperties,
        outPath: String,
        zipPath: String?,
        testLogPath: String,
        eventLoop: EventLoop,
        threadPool: NIOThreadPool,
        requestLogger: Logging.Logger?,
        testLogger: SwiftGen.Logger
    ) -> EventLoopFuture<Void> where Tracker.Persister == Persister {
        requestLogger?.info("Running tests in \(outPath)")

        let testProgressTracker = testProgressTracking?.0

        func trackProgress(_ progress: @autoclosure () -> Tracker?) -> EventLoopFuture<Void> {
            zip(progress(), testProgressTracking?.1)
                .map { $0.0.save(on: $0.1()) }
                ?? eventLoop.makeSucceededFuture(())
        }

        return prepOutputFolder(
            on: eventLoop,
            at: outPath,
            logger: testLogger
        )
        .flatMap { trackProgress(testProgressTracker?.markBuilding()) }
        .flatMap { openAPIDoc(on: eventLoop, from: testProperties.openAPISource, threadPool: threadPool) }
        .flatMapError { error in
            let errorString: String
            if let error = error as? Abort {
                errorString = "HTTP Error: \(error.status.code) - \(error.status.reasonPhrase)"
            } else {
                errorString = OpenAPI.Error(from: error).localizedDescription
            }
            testLogger.error(path: nil, context: "Prepping/Retrieving OpenAPI Source", message: errorString)
            return eventLoop.makeFailedFuture(error)
        }
        .flatMap { openAPIDoc in
            produceAPITestPackage(
                on: eventLoop,
                given: openAPIDoc,
                to: outPath,
                threadPool: threadPool,
                zipToPath: zipPath,
                testSuiteConfiguration: testProperties.testSuiteConfiguration,
                formatGeneratedSwift: testProperties.formatGeneratedSwift,
                logger: testLogger
            )
        }
        .flatMap { trackProgress(testProgressTracker?.markRunning()) }
        .flatMap {
            runAPITestPackage(
                on: eventLoop,
                at: outPath,
                threadPool: threadPool,
                testLogPath: testLogPath,
                logger: testLogger
            )
        }
        .flatMap { trackProgress(testProgressTracker?.markPassed()) }
        .always { _ in
            try? cleanupOutFolder(outPath, logger: testLogger)
            requestLogger?.info("Cleaning up tests in \(outPath)")
        }
        .flatMapError { error in
            if let requestLogger = requestLogger {
                requestLogger.error(
                    "Testing Failed",
                    metadata: ["error": .stringConvertible(String(describing: error))]
                )
                // following is tmp to workaround above metadata not being dumped to console with previous call:
                requestLogger.error("\(String(describing: error))")
            } else {
                testLogger.error(
                    path: nil,
                    context: "Testing Failed",
                    message: String(describing: error)
                )
            }

            // once finished tracking progress, just recreate a new failed future to return.
            return trackProgress(testProgressTracker?.markFailed())
                .flatMap { eventLoop.makeFailedFuture(error) }
        }
    }
}

// MARK: - Logger
extension APITestCommand {
    final class Logger: SwiftGen.Logger {
        let console: Console
        let enableWarnings: Bool

        init(console: Console, enableWarnings: Bool = true) {
            self.console = console
            self.enableWarnings = enableWarnings
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
            guard enableWarnings else { return }

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

        public func info(path: String?, context: String, message: String) {
            console.info("-> \(message)")
            console.print("--")
            console.print("-- \(context)")
            if let path = path {
                console.print("-- at [", newLine: false)
                console.info(path, newLine:  false)
                console.print("]")
            }
            console.print()
            console.print()
        }
    }
}

// MARK: - Helpers
public func prepOutputFolder(
    on loop: EventLoop,
    at outputPath: String,
    logger: SwiftGen.Logger
) -> EventLoopFuture<Void> {

    loop.submit { try prepOutFolder(outputPath, logger: logger) }
}

public func openAPIDoc(
    on loop: EventLoop,
    from source: OpenAPISource,
    threadPool: NIOThreadPool
) -> EventLoopFuture<ResolvedDocument> {
    /// Get the OpenAPI documentation from a URL
    func get(_ url: URI, credentials: (username: String, password: String)? = nil) -> EventLoopFuture<ResolvedDocument> {
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

        return client.execute(request: request).flatMap { (response) -> EventLoopFuture<HTTPClient.Response> in
            guard response.status == .ok else {
                return loop.makeFailedFuture(Abort(response.status))
            }
            return loop.makeSucceededFuture(response)
        }.flatMap { response in
            let content = ClientResponse(
                status: response.status,
                headers: response.headers,
                body: response.body
            )
            .content

            return threadPool.runIfActive(eventLoop: loop) {
                try content
                    .decode(OpenAPI.Document.self)
                    .locallyDereferenced()
                    .resolved()
            }
        }.always { _ in try! client.syncShutdown() }
    }

    switch source {
    case .file(path: let path):
        let filePath = URL(fileURLWithPath: path)

        if filePath.pathExtension == "yml" || filePath.pathExtension == "yaml" {
            let string = threadPool.runIfActive(eventLoop: loop) {
                try String(contentsOf: filePath)
            }

            let decoder = YAMLDecoder()

            return string.flatMap { string in
                threadPool.runIfActive(eventLoop: loop) {
                    try decoder.decode(OpenAPI.Document.self, from: string)
                        .locallyDereferenced()
                        .resolved()
                }
            }
        } else {
            let data = threadPool.runIfActive(eventLoop: loop) {
                try Data(contentsOf: filePath)
            }

            let decoder = JSONDecoder.custom(dates: .iso8601)

            return data.flatMap { data in
                threadPool.runIfActive(eventLoop: loop) {
                    try decoder.decode(OpenAPI.Document.self, from: data)
                        .locallyDereferenced()
                        .resolved()
                }
            }
        }

    case .basicAuth(url: let url,
                    username: let username,
                    password: let password):

        return get(url, credentials: (username: username, password: password))

    case .unauthenticated(url: let url):
        return get(url)
    }
}

public func produceAPITestPackage(
    on loop: EventLoop,
    given openAPIDoc: ResolvedDocument,
    to outputPath: String,
    threadPool: NIOThreadPool,
    zipToPath: String? = nil,
    testSuiteConfiguration: JSONAPISwiftGen.TestSuiteConfiguration,
    formatGeneratedSwift: Bool = true,
    logger: SwiftGen.Logger
) -> EventLoopFuture<Void> {
    threadPool.runIfActive(eventLoop: loop) {
        SwiftGen.produceAPITestPackage(
            from: openAPIDoc,
            outputTo: outputPath,
            zipToPath: zipToPath,
            testSuiteConfiguration: testSuiteConfiguration,
            formatGeneratedSwift: formatGeneratedSwift,
            logger: logger
        )
    }
}

public func runAPITestPackage(
    on loop: EventLoop,
    at outputPath: String,
    threadPool: NIOThreadPool,
    testLogPath: String,
    logger: SwiftGen.Logger
) -> EventLoopFuture<Void> {
    threadPool.runIfActive(eventLoop: loop) {
        try SwiftGen.runAPITestPackage(
            at: outputPath,
            testLogPath: testLogPath,
            logger: logger
        )
    }
}

internal struct URLOption: LosslessStringConvertible {
    let value: URL

    init?(_ description: String) {
        guard let url = URL(string: description) else {
            return nil
        }
        value = url
    }

    var description: String {
        return value.absoluteString
    }
}
