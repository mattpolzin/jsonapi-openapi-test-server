//
//  main.swift
//  APITesting
//
//  Created by Mathew Polzin on 9/28/19.
//

import APITesting
import Vapor

func configure(_ app: Application) {
    // Commands
    app.register(APITestCommand.self) { _ in
        return try .init()
    }
    app.register(CommandConfiguration.self) { container in
        var commandConfig = CommandConfiguration()
        commandConfig.use(container.make(APITestCommand.self), as: "test", isDefault: true)
        return commandConfig
    }
}

let app = Application(environment: try .detect())

configure(app)

try app.boot()
try app.run()
