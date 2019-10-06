//
//  ApiTestPackageCompile.swift
//  SwiftGen
//
//  Created by Mathew Polzin on 9/21/19.
//

import Foundation
import OpenAPIKit

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
        logger.warning(path: path, context: "While writing test logs to file", message: String(describing: error))
    }

    let testOutput = stdout.split(separator: "\n")

    func context<S>(for line: S) -> String where S: StringProtocol {
        if line.contains("test_example_parse") {
            return "Parse Example Test Case"

        } else if line.contains("test_example_request") {
            return "Request Example Test Case"
        }
        return "Test Case"
    }

    let failedTestLines = testOutput.filter { $0.contains(": error:") }
    let succeededTestLines = testOutput.filter { $0.contains(" passed (") }

    for line in succeededTestLines {
        let pathParseAttempt = line
            .components(separatedBy: "__")
            .dropFirst()
            .dropLast()
            .joined(separator: ", ")

        logger.success(path: pathParseAttempt.isEmpty ? path : pathParseAttempt,
                       context: "\(context(for: line)) Passed",
                       message: String(line))
    }

    guard failedTestLines.count == 0 else {
        for line in failedTestLines {

            let pathParseAttempt = line
                .components(separatedBy: "__")
                .dropFirst()
                .dropLast()
                .joined(separator: ", ")

            let isolatedError = line
                .components(separatedBy: "] : ")
                .last

            logger.error(path: pathParseAttempt.isEmpty ? path : pathParseAttempt,
                         context: "\(context(for: line)) Failed",
                         message: isolatedError ?? String(line))
        }
        throw TestPackageSwiftError.testsFailed(succeeded: succeededTestLines.count,
                                                failed: failedTestLines.count)
    }

    guard exitCode == shellSuccessCode else {
        throw TestPackageSwiftError.executionFailed(stdout: stdout)
    }
}

let shellSuccessCode: Int32 = 0

public enum TestPackageSwiftError: Swift.Error, CustomStringConvertible {
//    case compilationFailed
    case executionFailed(stdout: String)
    case testsFailed(succeeded: Int, failed: Int)

    public var description: String {
        switch self {
        case .executionFailed(stdout: let stdout):
            return "Failed to build & run tests with output:\n\(stdout)\n"

        case .testsFailed(succeeded: let succeeded, failed: let failed):
            return "\(failed)/\(succeeded + failed) Tests Failed."
        }
    }
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
