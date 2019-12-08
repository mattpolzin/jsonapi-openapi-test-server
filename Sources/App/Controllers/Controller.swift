//
//  ControllerProtocol.swift
//  App
//
//  Created by Mathew Polzin on 12/8/19.
//

import Vapor
import FluentKit
import SwiftGen

class Controller {}

// MARK: - Canned Responses
extension Controller {
    static func jsonServerError<ResponseBodyType: ResponseEncodable>() -> CannedResponse<ResponseBodyType> {
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
    }

    static func jsonBadRequestError<ResponseBodyType: ResponseEncodable>(details: String) -> CannedResponse<ResponseBodyType> {
        .init(response: Response(
            status: .badRequest,
            body: .init(data: try! JSONEncoder().encode(
                API.SingleAPITestDescriptorResponse.ErrorDocument(
                    apiDescription: .none,
                    errors: [
                        .error(.init(id: nil, title: "Bad Request", detail: details))
                    ]
                )
                ))
            )
        )
    }

    static func jsonNotFoundError<ResponseBodyType: ResponseEncodable>(details: String) -> CannedResponse<ResponseBodyType> {
        .init(response: Response(
            status: .notFound,
            body: .init(data: try! JSONEncoder().encode(
                API.SingleAPITestDescriptorResponse.ErrorDocument(
                    apiDescription: .none,
                    errors: [
                        .error(.init(id: nil, title: "Not Found", detail: details))
                    ]
                )
                ))
            )
        )
    }
}

// MARK: - SwiftGen Logger
extension Controller {
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
