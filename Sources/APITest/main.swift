//
//  main.swift
//  APITesting
//
//  Created by Mathew Polzin on 9/28/19.
//

import APITesting
import Vapor

func configure(_ services: inout Services) {
    // Commands
    services.register(APITestCommand.self) { _ in
        return try .init()
    }
    services.extend(CommandConfiguration.self) { commands, container in
        try commands.use(container.make(APITestCommand.self), as: "test", isDefault: true)
    }
}

let app = Application(environment: try .detect(),
                      configure: configure)

try app.boot()
try app.run()
