//
//  ApiTestPackageCompile.swift
//  SwiftGen
//
//  Created by Mathew Polzin on 9/21/19.
//

import Foundation

public func prepOutFolder(_ outPath: String, logger: Logger) throws {
    try? FileManager.default.removeItem(atPath: outPath + "/Tests/GeneratedAPITests")

    if !FileManager.default.fileExists(atPath: outPath + "/Tests/GeneratedAPITests/resourceObjects") {
        try FileManager.default.createDirectory(atPath: outPath + "/Tests/GeneratedAPITests/resourceObjects",
                                                withIntermediateDirectories: true,
                                                attributes: nil)
    }
}

public func runAPITestPackage(at path: String, logger: Logger) throws {
    let (exitCode, stdout) = shell("cd '\(path)' && swift test 2>&1")

    do {
        try stdout.write(toFile: path + "/api_tests.log",
                     atomically: true,
                     encoding: .utf8)
    } catch let error {
        logger.warning(context: "While writing test logs to file", message: String(describing: error))
    }

    let testOutput = stdout.split(separator: "\n")

    let failedTestLines = testOutput.filter { $0.contains(" failed: ") }

    guard failedTestLines.count == 0 else {
        for line in failedTestLines {
            logger.error(context: "Test Case Failed", message: String(line))
        }
        throw TestPackageSwiftError.testsFailed
    }

    guard exitCode == shellSuccessCode else {
        logger.error(context: "Failed Testing Details", message: stdout)
        throw TestPackageSwiftError.executionFailed
    }
}

let shellSuccessCode: Int32 = 0

public enum TestPackageSwiftError: Swift.Error {
//    case compilationFailed
    case executionFailed
    case testsFailed
}

@discardableResult
func shell(_ command: String) -> (Int32, String) {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    var data = Data()
    var newData: Data
    repeat {
        newData = pipe.fileHandleForReading.availableData
        data += newData
    } while !newData.isEmpty

    let output: String = String(data: data, encoding: .utf8)!

    task.waitUntilExit()
    return (task.terminationStatus, output)
}
