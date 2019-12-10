//
//  middleware.swift
//  App
//
//  Created by Mathew Polzin on 12/9/19.
//

import Vapor

func addMiddleware(_ app: Application) {
    app.middleware.use(
        ErrorMiddleware.default(environment: app.environment)
    )
    app.middleware.use(
        FileMiddleware(
            publicDirectory: DirectoryConfiguration.detect()
                .publicDirectory
        )
    )
}
