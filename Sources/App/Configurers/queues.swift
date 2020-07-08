//
//  queues.swift
//  App
//
//  Created by Mathew Polzin on 7/4/20.
//

import Foundation
import Vapor
import Queues

public func addQueues(_ app: Application) throws {
    try app.queues.use(.redis(url: Environment.redisURL()))
    
    let apiTestJob = APITestJob()
    app.queues.add(apiTestJob)

    if Environment.inProcessJobs {
        try app.queues.startInProcessJobs(on: .default)
    }
}
