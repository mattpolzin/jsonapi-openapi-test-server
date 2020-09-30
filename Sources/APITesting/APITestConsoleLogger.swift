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

    private(set) var warningCount: Int
    private(set) var errorCount: Int
    private(set) var successCount: Int

    init(console: Console, enableWarnings: Bool = true) {
        self.console = console
        self.enableWarnings = enableWarnings
        self.warningCount = 0
        self.errorCount = 0
        self.successCount = 0
    }

    public func error(path: String?, context: String, message: String) {
        errorCount += 1
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
        warningCount += 1
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
        successCount += 1
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
