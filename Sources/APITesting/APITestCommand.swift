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

        try prepOutputFolder(on: eventLoop, at: path, logger: logger)
//            .flatMap { descriptor.markBuilding().save(on: database) }
            .flatMap { openAPIDoc(on: eventLoop, from: source) }
            .flatMap { openAPIDoc in produceAPITestPackage(on: eventLoop, given: openAPIDoc, to: path, logger: logger) }
//            .flatMap { descriptor.markRunning().save(on: database) }
            .flatMap { runAPITestPackage(on: eventLoop, at: path, logger: logger) }
//            .flatMap { descriptor.markPassed().save(on: database) }
            .recover { err in
                logger.error(path: nil,
                             context: "Testing Failed",
                             message: String(describing: err))
                //                let _ = descriptor.markFailed().save(on: database)
            }
            .wait()
    }

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
                                         logger: SwiftGen.Logger) -> EventLoopFuture<Void> {
    loop.submit { SwiftGen.produceAPITestPackage(from: openAPIDoc, outputTo: outputPath, logger: logger) }
}

public func runAPITestPackage(on loop: EventLoop,
                                     at outputPath: String,
                                     logger: SwiftGen.Logger) -> EventLoopFuture<Void> {
    loop.submit { try SwiftGen.runAPITestPackage(at: outputPath, logger: logger) }
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
