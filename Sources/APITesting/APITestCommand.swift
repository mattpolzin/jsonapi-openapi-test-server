//
//  APITestCommand.swift
//  App
//
//  Created by Mathew Polzin on 9/28/19.
//

import Foundation
import ArgumentParser
import Vapor
import Yams
import PureSwiftJSON
import SwiftGen
import OpenAPIKit
import JSONAPISwiftGen

extension APITestProperties.Parser: ExpressibleByArgument {}

internal struct URLOption: LosslessStringConvertible, ExpressibleByArgument {
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

public struct APITestCommand: ParsableCommand {
    public static let configuration: CommandConfiguration = .init(
        commandName: "APITest",
        abstract: "Build and run tests based on an OpenAPI Document."
    )

    @ArgumentParser.Option(
        name: .customLong("dump-files"),
        help: .init(
            "Dump produced test files in a zipped file at the specified location.",
            discussion: """
                Tip: A good location to dump files is "./out". For the Dockerized tool this will be `/app/out` and when running the tool natively on your machine this will be the `out` folder relative to the current working directory.

                Not using this argument will result in test files being deleted after execution of the tests.
                """,
            valueName: "directory path"
        )
    )
    var dumpFilesPath: String?

    @ArgumentParser.Flag(
        name: [.long, .short],
        help: .init(
            "Produce a non-zero exit code if any tests fail."
        )
    )
    var failHard: Bool = false

    @ArgumentParser.Flag(
        help: .init("Do not print warnings in the output.")
    )
    var ignoreWarnings: Bool = false

    @ArgumentParser.Option(
        name: .customLong("openapi-file"),
        help: .init(
            "Specify a filename from the local filesystem from which to read OpenAPI documentation.",
            discussion: """
                Alternatively, set the `API_TEST_IN_FILE` environment variable.

                Either the environment variable or this argument must be used to indicate the OpenAPI file from which the tests should be generated.
                """,
            valueName: "file path"
        )
    )
    var openAPIFile: String?

    @ArgumentParser.Option(
        name: .long,
        help: .init(
            "Override the server definition(s) in the OpenAPI document for the purposes of this test run.",
            discussion: """
                This argument allows you to make API requests against a different server than the input OpenAPI documentation specifies for this test run.

                Not using this argument will result in the API server options from the OpenAPI documentation being used.
                """,
            valueName: "url"
        )
    )
    var overrideServer: URLOption?

    @ArgumentParser.Option(
        name: [.long, .short],
        help: .init(
            "Choose between the \"stable\" parser and a \"fast\" parser that is less battle-tested.",
            discussion: """
                This argument is currently only applicable to JSON parsing. When decoding a YAML file, the argument is ignored as there is only currently one YAML parser to choose from.

                Not using this argument will result in using the default stable parser.
                """,
            valueName: "parser"
        )
    )
    var parser: APITestProperties.Parser = .stable

    public init() {}

    public func run() throws {
        let testEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let outPath: String = Environment.outPath

        let console = Terminal()

        let logger = Logger(console: console, enableWarnings: !ignoreWarnings)

        let source: OpenAPISource = try openAPIFile.map { .file(path: $0) } ?? .detect()
        let path = outPath

        let cwd = FileManager.default.currentDirectoryPath

        let zipToArg = dumpFilesPath.map { "\($0)/api_test_files.zip" }
        let testLogPath = dumpFilesPath.map { "\($0)/api_test.log" } ?? cwd + "/out/api_test.log"

        let formatGeneratedSwift: Bool
        #if swift(>=5.3)
        formatGeneratedSwift = false
        #else
        // format the Swift files only if the result is being dumped for later consumption
        formatGeneratedSwift = dumpFilesPath != nil
        #endif

        let testProperties = APITestProperties(
            openAPISource: source,
            apiHostOverride: overrideServer?.value,
            formatGeneratedSwift: formatGeneratedSwift,
            parser: parser
        )

        console.print()

        let testEventLoop = testEventLoopGroup.next()
        let threadPool = NIOThreadPool(numberOfThreads: 1)
        threadPool.start()

        let future = Self.kickTestsOff(
            testProperties: testProperties,
            outPath: path,
            zipPath: zipToArg,
            testLogPath: testLogPath,
            eventLoop: testEventLoop,
            threadPool: threadPool,
            testLogger: logger
        ).recover { _ in
            if self.failHard {
                Self.exit(withError: ExitCode(1))
            }
        }

        try future
            .wait()

        try threadPool.syncShutdownGracefully()
        try testEventLoopGroup.syncShutdownGracefully()
    }
}

extension APITestCommand {

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

        let kickOffTime = time(nil)

        func logDuration<T>(tag: String) -> (_ input: T) -> T {
            return { input in
                requestLogger?.info("Time elapsed when '\(tag)': \(time(nil) - kickOffTime)")
                return input
            }
        }

        func trackProgress(_ progress: @autoclosure () -> Tracker?) -> EventLoopFuture<Void> {
            return zip(progress(), testProgressTracking?.1)
                .map { $0.0.save(on: $0.1()) }
                ?? eventLoop.makeSucceededFuture(())
        }

        return prepOutputFolders(
            on: eventLoop,
            at: outPath,
            testLogPath: testLogPath,
            logger: testLogger
        )
        .flatMap { trackProgress(testProgressTracker?.markBuilding()) }
        .flatMap {
            openAPIDoc(
                on: eventLoop,
                from: testProperties.openAPISource,
                parser: testProperties.parser,
                threadPool: threadPool
            )
        }
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
        .map(logDuration(tag: "Done Parsing Document"))
        .flatMap { openAPIDoc in
            produceValidationErrors(
                document: openAPIDoc,
                on: eventLoop,
                logger: testLogger
            )
        }
        .map(logDuration(tag: "Done Validating Document"))
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
        .map(logDuration(tag: "Done Producing Test Package"))
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
            logDuration(tag: "Done Cleaning Up")(())
        }
        .flatMapError { error in
            if let requestLogger = requestLogger {
                requestLogger.error(
                    "Testing Failed: \(String(describing: error))"
                )
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
    typealias Logger = APITestConsoleLogger
}

// MARK: - Helpers
public func prepOutputFolders(
    on loop: EventLoop,
    at outputPath: String,
    testLogPath: String,
    logger: SwiftGen.Logger
) -> EventLoopFuture<Void> {

    loop.submit { try prepOutFolders(outputPath, testLogPath: testLogPath, logger: logger) }
}

public func openAPIDoc(
    on loop: EventLoop,
    from source: OpenAPISource,
    parser: APITestProperties.Parser,
    threadPool: NIOThreadPool
) -> EventLoopFuture<ResolvedDocument> {
    /// Get the OpenAPI documentation from a URL
    func get(_ url: URI, credentials: (username: String, password: String)? = nil) -> EventLoopFuture<ResolvedDocument> {
        let client = HTTPClient(eventLoopGroupProvider: .shared(loop))

        var headers = HTTPHeaders()
        if let (username, password) = credentials {
            headers.add(
                name: .authorization,
                value: HTTPClient.Authorization.basic(
                    username: username,
                    password: password
                ).headerValue
            )
        }

        let request: HTTPClient.Request
        do {
            request = try HTTPClient.Request(
                url: url.string,
                method: .GET,
                headers: headers
            )
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
            let fileIO = NonBlockingFileIO(threadPool: threadPool)

            let handleAndRegion = fileIO.openFile(
                path: filePath.path,
                eventLoop: loop
            )

            let data: EventLoopFuture<ByteBuffer> = handleAndRegion.flatMap { (handle, region) in
                let contents = fileIO.read(
                    fileRegion: region,
                    allocator: .init(),
                    eventLoop: loop
                )
                contents.whenComplete { _ in try? handle.close() }
                return contents
            }

            return data.flatMap { data in
                threadPool.runIfActive(eventLoop: loop) {
                    let document: OpenAPI.Document
                    switch parser {
                    case .stable:
                        document = try JSONDecoder().decode(OpenAPI.Document.self, from: data)
                    case .fast:
                        document = try PSJSONDecoder().decode(OpenAPI.Document.self, from: data.readableBytesView)
                    }
                    return try document
                        .locallyDereferenced()
                        .resolved()
                }
            }
        }

    case .basicAuth(url: let url, username: let username, password: let password):

        return get(url, credentials: (username: username, password: password))

    case .unauthenticated(url: let url):
        return get(url)
    }
}

/// Produces validation errors as side effects
/// via the given logger.
public func produceValidationErrors(
    document: ResolvedDocument,
    on loop: EventLoop,
    logger: SwiftGen.Logger
) -> EventLoopFuture<ResolvedDocument> {
    let validator = Validator()
        .validating(.documentContainsPaths)
        .validating(.pathsContainOperations)
        .validating(.schemaComponentsAreDefined)

    do {
        try document
            .underlyingDocument
            .underlyingDocument
            .validate(using: validator)
    } catch let errors as ValidationErrorCollection {
        for error in errors.values {
            logger.error(
                path: error.codingPathString,
                context: "Validating OpenAPI Documentation",
                message: error.reason
            )
        }
    } catch let error {
        return loop.makeFailedFuture(error)
    }

    return loop.makeSucceededFuture(document)
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
