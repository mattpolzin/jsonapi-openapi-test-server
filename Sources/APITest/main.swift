//
//  main.swift
//  APITesting
//
//  Created by Mathew Polzin on 9/28/19.
//

import APITesting
import Vapor

func configure(_ app: Application) throws {
    // Commands
    try app.commands.use(APITestCommand(), as: "test", isDefault: true)
}

let app = Application(try .detect())

try configure(app)

try app.boot()
try app.run()
