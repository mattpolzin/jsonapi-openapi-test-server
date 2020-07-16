//
//  APITestConsoleLogger.swift
//  APITesting
//
//  Created by Mathew Polzin on 7/14/20.
//

import Foundation
import SwiftGen
import Vapor

final class APITestConsoleLogger: SwiftGen.Logger {
    let console: Console
    let enableWarnings: Bool

    init(console: Console, enableWarnings: Bool = true) {
        self.console = console
        self.enableWarnings = enableWarnings
    }

    public func error(path: String?, context: String, message: String) {
        console.error("!> \(message)")
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
        guard enableWarnings else { return }

        console.warning("*> \(message)")
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

    public func info(path: String?, context: String, message: String) {
        console.info("-> \(message)")
        console.print("--")
        console.print("-- \(context)")
        if let path = path {
            console.print("-- at [", newLine: false)
            console.info(path, newLine:  false)
            console.print("]")
        }
        console.print()
        console.print()
    }
}
