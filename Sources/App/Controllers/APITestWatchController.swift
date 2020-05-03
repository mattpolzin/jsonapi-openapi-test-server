//
//  APITestWatchController.swift
//  
//
//  Created by Mathew Polzin on 4/9/20.
//

import Foundation
import Vapor
import PostgresNIO
import Fluent
import PostgresKit
import VaporTypedRoutes
import APIModels

class APITestWatchController: Controller {

    struct Watcher {
        let websocket: WebSocket
        let request: Request
    }

    private var nextWatcherId: Int = 0
    private(set) var watchers: [Int: Watcher] = [:]

    override fileprivate init() {}

    static func dummyWatcher() -> APITestWatchController {
        return .init()
    }

    func watch(req: Request, ws: WebSocket) {
        let watcherId = nextWatcherId
        nextWatcherId += 1

        watchers[watcherId] = .init(websocket: ws, request: req)

        let _ = ws.onClose.always { [weak self] result in
            switch result {
            case .failure(let error):
                // TODO
                print(error)
            default:
                break
            }
            self?.watchers.removeValue(forKey: watcherId)
        }

        startListening()
    }

    fileprivate func startListening() {
        fatalError("Use a subclass for an implementation of this method.")
    }
}

/// Controls WebSocket watching on API Tests.
final class DatabaseAPITestWatchController: APITestWatchController {

    let db: PostgresDatabase
    let testController: APITestController

    private var dbConnection: PostgresConnection?

    init(watching db: PostgresDatabase, with testController: APITestController) {
        self.db = db
        self.testController = testController
        super.init()
    }

    override fileprivate func startListening() {
        guard dbConnection == nil else { return }

        let _ = withSustainedConnection { connection in
            connection.addListener(channel: "api_test_descriptors_updated") { context, response in
                guard let id = UUID(uuidString: response.payload).map(API.APITestDescriptor.Id.init(rawValue:)) else {
                    self.db.logger.error("Failed to create a UUID from trigger payload: \(response.payload)")
                    return
                }
                self.sendNotificationsFor(test: id)
            }

            let _ = connection.query("LISTEN api_test_descriptors_updated")

            connection.addListener(channel: "api_test_messages_updated") { context, response in
                guard let id = UUID(uuidString: response.payload).map(API.APITestMessage.Id.init(rawValue:)) else {
                    self.db.logger.error("Failed to create a UUID from trigger payload: \(response.payload)")
                    return
                }
                self.sendNotificationsFor(message: id)
            }

            let _ = connection.query("LISTEN api_test_messages_updated")
        }
    }

    private func sendNotificationsFor(test testId: API.APITestDescriptor.Id) {
        db.logger.info("notifying \(watchers.count) watchers of test update.")
        let result = testController.showResults(
            id: testId.rawValue,
            shouldIncludeMessages: false,
            shouldIncludeProperties: (false, alsoIncludeSource: false),
            db: db as! Database
        )

        for watcher in watchers.values {
            let typedRequest = TypedRequest<APITestController.ShowContext>(underlyingRequest: watcher.request)

            result.flatMap(typedRequest.response.success.encode)
                .flatMapError { _ in typedRequest.response.serverError }
                .whenSuccess { response in
                    guard let responseString = response.body.string else {
                        // error?
                        return
                    }
                    watcher.websocket.send(responseString)
            }
        }
    }

    private func sendNotificationsFor(message messageId: API.APITestMessage.Id) {
        db.logger.info("notifying \(watchers.count) watchers of message update.")
        let result = APITestMessageController.showResults(
            id: messageId.rawValue,
            shouldIncludeTestDescriptor: true,
            db: db as! Database
        )

        for watcher in watchers.values {
            let typedRequest = TypedRequest<APITestMessageController.ShowContext>(underlyingRequest: watcher.request)

            result.flatMap(typedRequest.response.success.encode)
                .flatMapError { _ in typedRequest.response.serverError }
                .whenSuccess { response in
                    guard let responseString = response.body.string else {
                        // error?
                        return
                    }
                    watcher.websocket.send(responseString)
            }
        }
    }

    private func withSustainedConnection(_ closure: @escaping (PostgresConnection) -> Void) -> EventLoopFuture<Void> {
        guard let connection = dbConnection else {
            return db.withConnection { connection in
                self.dbConnection = connection
                closure(connection)
                return self.db.eventLoop.makeSucceededFuture(())
            }
        }
        closure(connection)
        return db.eventLoop.makeSucceededFuture(())
    }

    deinit {
        for watcher in watchers.values {
            let _ = watcher.websocket.close(code: .goingAway)
        }
    }
}

extension APITestWatchController {
    public func mount(on app: Application, at rootPath: RoutingKit.PathComponent...) {
        app.webSocket("watch", onUpgrade: self.watch)
            .tags("Monitoring")
            .summary("Watch for progress on API Tests")
            .description("""
This **WebSocket** route will send a message every time a test starts, progresses, finishes, etc.

The message will contain a JSON:API response payload with the APITestDescriptor for the updated test.
"""
        )
    }
}
