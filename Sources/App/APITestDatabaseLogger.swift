//
//  APITestDatabaseLogger.swift
//  App
//
//  Created by Mathew Polzin on 7/14/20.
//

import Foundation
import FluentKit
import SwiftGen

final class APITestDatabaseLogger: SwiftGen.Logger {
    let systemLogger: Logging.Logger
    let descriptor: DB.APITestDescriptor
    let eventLoop: EventLoop
    let database: () -> Database

    init(
        systemLogger: Logging.Logger,
        descriptor: DB.APITestDescriptor,
        eventLoop: EventLoop,
        database: @escaping () -> Database
    ) {
        self.systemLogger = systemLogger
        self.descriptor = descriptor
        self.eventLoop = eventLoop
        self.database = database
    }

    public func error(path: String?, context: String, message: String) {
        systemLogger.error("\(message)", metadata: ["context": .string(context)])
        let _ = eventLoop.submit {
            try DB.APITestMessage(
                testDescriptor: self.descriptor,
                messageType: .error,
                path: path,
                context: context.isEmpty ? nil : context,
                message: message
            ).save(on: self.database())
        }
    }

    public func warning(path: String?, context: String, message: String) {
        systemLogger.warning("\(message)", metadata: ["context": .string(context)])
        let _ = eventLoop.submit {
            try DB.APITestMessage(
                testDescriptor: self.descriptor,
                messageType: .warning,
                path: path,
                context: context.isEmpty ? nil : context,
                message: message
            ).save(on: self.database())

        }
    }

    public func success(path: String?, context: String, message: String) {
        systemLogger.info("\(message)", metadata: ["context": .string(context)])
        let _ = eventLoop.submit {
            try DB.APITestMessage(
                testDescriptor: self.descriptor,
                messageType: .success,
                path: path,
                context: context.isEmpty ? nil : context,
                message: message
            ).save(on: self.database())
        }
    }

    public func info(path: String?, context: String, message: String) {
        systemLogger.info("\(message)", metadata: ["context": .string(context)])
        let _ = eventLoop.submit {
            try DB.APITestMessage(
                testDescriptor: self.descriptor,
                messageType: .info,
                path: path,
                context: context.isEmpty ? nil : context,
                message: message
            ).save(on: self.database())
        }
    }
}
