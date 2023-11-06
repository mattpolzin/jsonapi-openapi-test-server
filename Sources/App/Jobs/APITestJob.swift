//
//  APITestJob.swift
//  App
//
//  Created by Mathew Polzin on 7/4/20.
//

import Foundation
import Vapor
import Queues
import APITesting
import Fluent
import SwiftGen

struct APITestJob: Job {

    struct Payload: Codable {
        let descriptor: DB.APITestDescriptor
        let properties: DB.APITestProperties
        let source: DB.OpenAPISource

        let outputPath: String
    }

    func dequeue(_ context: QueueContext, _ payload: Payload) -> EventLoopFuture<Void> {
        let database = { context.application.databases
            .database(
                .psql,
                logger: context.logger,
                on: context.eventLoop
            )!
        }

        let outPath = APITestController.outPath(for: payload.descriptor, root: payload.outputPath)
        let testLogPath = APITestController.testLogPath(for: payload.descriptor)
        let zipPath = APITestController.zipPath(for: payload.descriptor)

        let swiftGenSource = OpenAPISource(payload.source)

        let formatGeneratedSwift: Bool
        #if swift(>=5.3)
        formatGeneratedSwift = false
        #else
        formatGeneratedSwift = true
        #endif

        let testProperties = APITestProperties(
            openAPISource: swiftGenSource,
            apiHostOverride: payload.properties.apiHostOverride,
            formatGeneratedSwift: formatGeneratedSwift
        )

        let testLogger = Controller.Logger(
            systemLogger: context.logger,
            descriptor: payload.descriptor,
            eventLoop: context.eventLoop,
            database: database
        )

        func descriptor(in db: Database) -> EventLoopFuture<DB.APITestDescriptor> {
            return DB.APITestDescriptor
                .find(payload.descriptor.id, on: db)
                // TODO: create a new error to throw here for "test deleted from database before testing finished."
                .unwrap(or: Abort(.notFound))
        }

        return descriptor(in: database()).flatMap { descriptor in
            return APITestCommand.kickTestsOff(
                testProgressTracking: (descriptor, database),
                testProperties: testProperties,
                outPath: outPath,
                zipPath: zipPath,
                testLogPath: testLogPath,
                eventLoop: context.eventLoop,
                threadPool: context.application.threadPool,
                requestLogger: context.logger,
                testLogger: testLogger
            )
            .flatMapError { error in
                // if the error is actually "successfully ran tests,
                // but the tests failed, we do not want to reschedule
                // the job so we will map it to a successful job
                // completion.
                if let testFailure = error as? TestPackageSwiftError,
                   case .testsFailed = testFailure {
                    return context.eventLoop.makeSucceededFuture(())
                }
                // let errors fall through if not meeting criteria above.
                return context.eventLoop.makeFailedFuture(error)
            }
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Payload) -> EventLoopFuture<Void> {
        return context.eventLoop.future()
    }
}
