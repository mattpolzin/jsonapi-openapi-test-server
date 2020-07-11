//
//  ApiTestPackageSwiftGen.swift
//
//
//  Created by Mathew Polzin on 7/27/19.
//

import Foundation
import OpenAPIKit
import JSONAPISwiftGen
import ZIPFoundation

public protocol Logger {
    func error(path: String?, context: String, message: String)
    func warning(path: String?, context: String, message: String)
    func success(path: String?, context: String, message: String)
    func info(path: String?, context: String, message: String)
}

typealias HttpMethod = OpenAPI.HttpMethod

public func produceAPITestPackage(
    from openAPIDocument: ResolvedDocument,
    outputTo outPath: String,
    zipToPath: String? = nil,
    testSuiteConfiguration: TestSuiteConfiguration,
    formatGeneratedSwift: Bool = true,
    logger: Logger? = nil
) {
    produceAPITestPackage(
        for: openAPIDocument.routes,
        originatingAt: openAPIDocument.servers.first!,
        outputTo: outPath,
        zipToPath: zipToPath,
        testSuiteConfiguration: testSuiteConfiguration,
        formatGeneratedSwift: formatGeneratedSwift,
        logger: logger
    )
}

public func produceAPITestPackage(
    for routes: [ResolvedRoute],
    originatingAt server: OpenAPI.Server,
    outputTo outPath: String,
    zipToPath: String? = nil,
    testSuiteConfiguration: TestSuiteConfiguration,
    formatGeneratedSwift: Bool = true,
    logger: Logger? = nil
) {

    let testDir = outPath + "/Tests/GeneratedAPITests"
    let resourceObjDir = testDir + "/resourceObjects"

    func code<T: SwiftCodeRepresentable>(_ codeRepresentation: T) throws -> String {
        if formatGeneratedSwift {
            return try codeRepresentation.formattedSwiftCode()
        }
        return codeRepresentation.swiftCode
    }

    func code(for decl: Decl) throws -> String {
        if formatGeneratedSwift {
            return try decl.formattedSwiftCode()
        }
        return decl.swiftCode
    }

    let additionalLineSeparator = formatGeneratedSwift ? "" : "\n"

    // generate namespaces first
    let contents = try! namespaceDecls(for: routes)
        .map { try code(for: $0.enumDecl) }
        .joined(separator: "\n\n")
    try! write(contents: contents,
          toFileAt: testDir + "/",
          named: "Namespaces.swift")

    // write test helper to file
    let testHelperContents = try! [
        Import.Foundation as Decl,
        Import.JSONAPI as Decl,
        Import.JSONAPITesting as Decl,
        Import.AnyCodable as Decl,
        Import.XCTest as Decl,
        Import.FoundationNetworking,
        APIRequestTestSwiftGen.testFuncDecl,
        OpenAPIExampleParseTestSwiftGen.testFuncDecl
        ].map(code)
        .joined(separator: additionalLineSeparator)
    try! write(
        contents: testHelperContents,
        toFileAt: testDir + "/",
        named: "TestHelpers.swift"
    )

    try! write(
        contents: packageFile,
        toFileAt: outPath + "/",
        named: "Package.swift"
    )

    try! write(
        contents: linuxMainFile,
        toFileAt: outPath + "/Tests/",
        named: "LinuxMain.swift"
    )

    let results: [
        (
            endpoint: ResolvedEndpoint,
            documentFileNameString: String,
            apiRequestTest: APIRequestTestSwiftGen?,
            requestDocument: DataDocumentSwiftGen?,
            responseDocuments: [OpenAPI.Response.StatusCode : DataDocumentSwiftGen],
            testFunctionNames: [TestFunctionName]
        )
    ]
    results = routes.flatMap(\.endpoints).map { endpoint in

        let documentFileNameString = documentTypeName(path: endpoint.path, verb: endpoint.method)

        let apiRequestTest = try? APIRequestTestSwiftGen(
            server: server,
            pathComponents: endpoint.path,
            parameters: endpoint.parameters
        )

        let responseDocuments = documents(
            for: endpoint,
            on: server,
            testSuiteConfiguration: testSuiteConfiguration,
            logger: logger
        )

        let requestDocument: DataDocumentSwiftGen?
        do {
            try requestDocument = endpoint
                .requestBody
                .flatMap {
                    try document(
                        from: $0,
                        for: endpoint.method,
                        at: endpoint.path,
                        logger: logger
                    )
            }
        } catch let err {
            logger?.warning(
                path: endpoint.path.rawValue,
                context: "Parsing request document for \(endpoint.method.rawValue)",
                message: String(describing: err)
            )
            requestDocument = nil
        }

        let responseTestFunctionNames = responseDocuments
            .values
            .flatMap { doc in
                doc.testExampleFuncs.map { $0.testFunctionContext }
        }.map { context in
            TestFunctionName(
                path: endpoint.path,
                endpoint: endpoint.method,
                direction: .response,
                context: context
            )
        }

        let requestTestFunctionNames = requestDocument
            .map { doc in
                doc.testExampleFuncs
                    .map { $0.testFunctionContext }
                    .map { context in
                        TestFunctionName(
                            path: endpoint.path,
                            endpoint: endpoint.method,
                            direction: .request,
                            context: context
                        )
                }
        } ?? []

        return (
            endpoint: endpoint,
            documentFileNameString: documentFileNameString,
            apiRequestTest: apiRequestTest,
            requestDocument: requestDocument,
            responseDocuments: responseDocuments,
            testFunctionNames: responseTestFunctionNames + requestTestFunctionNames
        )
    }

    for result in results {
        try! writeResourceObjectFiles(
            toPath: resourceObjDir + "/\(result.documentFileNameString)_response_",
            for: result.responseDocuments.values,
            extending: namespace(
                for: OpenAPI.Path(result.endpoint.path.components + [result.endpoint.method.rawValue, "Response"])
            ),
            formatGeneratedSwift: formatGeneratedSwift
        )

        if let reqDoc = result.requestDocument {
            try! writeResourceObjectFiles(
                toPath: resourceObjDir + "/\(result.documentFileNameString)_request_",
                for: [reqDoc],
                extending: namespace(
                    for: OpenAPI.Path(result.endpoint.path.components + [result.endpoint.method.rawValue, "Request"])
                ),
                formatGeneratedSwift: formatGeneratedSwift
            )
        }

        // write API file
        try! writeAPIFile(
            toPath: testDir + "/\(result.documentFileNameString)_",
            for: result.apiRequestTest,
            reqDoc: result.requestDocument,
            respDocs: result.responseDocuments.values,
            httpVerb: result.endpoint.method,
            extending: namespace(for: result.endpoint.path),
            formatGeneratedSwift: formatGeneratedSwift
        )
    }

    let testClassFileContents = XCTestClassSwiftGen(
        className: "GeneratedTests",
        importNames: [],
        testFunctionNames: results.flatMap { $0.testFunctionNames }
    )
    try! write(
        contents: try! code(testClassFileContents),
        toFileAt: testDir + "/",
        named: "GeneratedTests.swift"
    )

    if let zipToPath = zipToPath {
        try! archive(from: outPath, to: zipToPath)
    }

    // a bit of diagnostic info
    let totalRouteCount = routes.count
    let totalEndpointCount = routes.map { $0.endpoints.count }.reduce(0, +)
    let totalTestCases = results.map { $0.testFunctionNames.count }.reduce(0, +)
    logger?.info(
        path: nil,
        context: "Processing Entire OpenAPI Document",
        message: "Created \(totalTestCases) test cases across \(totalEndpointCount) endpoints mounted at \(totalRouteCount) routes."
    )
}

func swiftTypeName(from string: String) -> String {
    return string
        .replacingOccurrences(of: "{", with: "")
        .replacingOccurrences(of: "}", with: "")
        .replacingOccurrences(of: " ", with: "_")
}

func namespace(for path: OpenAPI.Path) -> String {
    return path.components
        .map(swiftTypeName)
        .joined(separator: ".")
}

func documentTypeName(
    path: OpenAPI.Path,
    verb: HttpMethod
) -> String {
    let pathSnippet = swiftTypeName(from: path.components
        .joined(separator: "_"))

    return [pathSnippet, verb.rawValue].joined(separator: "_")
}

func writeResourceObjectFiles<T: Sequence>(
    toPath path: String,
    for documents: T,
    extending namespace: String,
    formatGeneratedSwift: Bool = true
) throws where T.Element == DataDocumentSwiftGen {
    for document in documents {

        let resourceObjectGenerators = document.resourceObjectGenerators

        let definedResourceObjectNames = Set(resourceObjectGenerators
            .flatMap { $0.exportedSwiftTypeNames })

        try resourceObjectGenerators
            .forEach { resourceObjectGen in

                try resourceObjectGen
                    .relationshipStubGenerators
                    .filter { !definedResourceObjectNames.contains($0.resourceTypeName) }
                    .forEach { stubGen in

                        // write relationship stub files
                        try writeFile(
                            toPath: path,
                            for: stubGen,
                            extending: namespace,
                            formatGeneratedSwift: formatGeneratedSwift
                        )
                }

                // write resource object files
                try writeFile(
                    toPath: path,
                    for: resourceObjectGen,
                    extending: namespace,
                    formatGeneratedSwift: formatGeneratedSwift
                )
        }
    }
}

/// Take the API request and request documents and response documents
/// and wrap them in a nested namespace structure.
///
/// Example:
/// ```
/// enum GET {
///     func test_request(...) { ... }
///
///     enum Request {
///         typealias Document = ...
///     }
///     enum Response {
///         typealias Document_200 = ...
///         typealias Document_201 = ...
///     }
/// }
/// ```
func apiDocumentsBlock<T: Sequence>(
    request: APIRequestTestSwiftGen?,
    requestDoc: DataDocumentSwiftGen?,
    responseDocs: T,
    httpVerb: HttpMethod
) -> Decl where T.Element == DataDocumentSwiftGen {
    let requestDocAndExample = requestDoc.map { doc in
        doc.decls
            + (doc.exampleGenerator?.decls ?? [])
            + doc.testExampleFuncs.flatMap { $0.decls }
    }

    let requestBlock = requestDocAndExample
        .map {
            BlockTypeDecl.enum(typeName: "Request",
                               conformances: nil,
                               $0)
    }

    let responseDocsAndExamples = responseDocs.flatMap { doc in
        doc.decls
            + (doc.exampleGenerator?.decls ?? [])
            + doc.testExampleFuncs.flatMap { $0.decls }
    }

    let responseBlock = BlockTypeDecl.enum(
        typeName: "Response",
        conformances: nil,
        responseDocsAndExamples
    )

    let verbBlock = BlockTypeDecl.enum(
        typeName: httpVerb.rawValue,
        conformances: nil,
        [requestBlock, responseBlock].compactMap { $0 } + (request?.decls ?? [])
    )

    return verbBlock
}

extension Decl {
    func extending(namespace: String) -> Decl {
        return BlockTypeDecl.extension(
            typeName: namespace,
            conformances: nil,
            conditions: nil,
            [self]
        )
    }
}

func writeAPIFile<T: Sequence>(
    toPath path: String,
    for request: APIRequestTestSwiftGen?,
    reqDoc: DataDocumentSwiftGen?,
    respDocs: T,
    httpVerb: HttpMethod,
    extending namespace: String,
    formatGeneratedSwift: Bool = true
) throws where T.Element == DataDocumentSwiftGen {

    let apiDecl = apiDocumentsBlock(
        request: request,
        requestDoc: reqDoc,
        responseDocs: respDocs,
        httpVerb: httpVerb
    )
        .extending(namespace: namespace)

    let outputFileContents = try! [
        Import.Foundation as Decl,
        Import.JSONAPI as Decl,
        Import.AnyCodable as Decl,
        Import.XCTest as Decl,
        apiDecl
        ].map {
            formatGeneratedSwift
                ? try $0.formattedSwiftCode()
                : $0.swiftCode
        }
        .joined(separator: formatGeneratedSwift ? "" : "\n")

    try write(
        contents: outputFileContents,
        toFileAt: path,
        named: "API.swift"
    )
}

func writeFile<T: ResourceTypeSwiftGenerator>(
    toPath path: String,
    for resourceObject: T,
    extending namespace: String,
    formatGeneratedSwift: Bool = true
) throws {

    let swiftTypeName = resourceObject.resourceTypeName

    let decl = BlockTypeDecl.extension(
        typeName: namespace,
        conformances: nil,
        conditions: nil,
        resourceObject.decls
    )

    let outputFileContents = try! (
            [
                Import.JSONAPI,
                Import.AnyCodable,
                decl
            ] as [Decl]
        )
        .map {
            formatGeneratedSwift
                ? try $0.formattedSwiftCode()
                : $0.swiftCode
        }
        .joined(separator: "\n")

    try write(
        contents: outputFileContents,
        toFileAt: path,
        named: "\(swiftTypeName).swift"
    )
}

func write(contents: String, toFileAt path: String, named name: String) throws {
    try contents.write(
        toFile: path + name,
        atomically: true,
        encoding: .utf8
    )
}

func archive(from sourcePath: String, to archiveFilePath: String) throws {
    let fileManager = FileManager.default

    let source = URL(fileURLWithPath: sourcePath)
    let destination = URL(fileURLWithPath: archiveFilePath)

    let archiveFolderPath = destination
        .deletingLastPathComponent()
        .path

    // create the directory if needed
    if !fileManager.fileExists(atPath: archiveFolderPath) {
        try fileManager.createDirectory(
            atPath: archiveFolderPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // delete a previously generated archive if needed
    if fileManager.fileExists(atPath: archiveFilePath) {
        try fileManager.removeItem(atPath: archiveFilePath)
    }

    try fileManager.zipItem(at: source, to: destination)
}

struct DeclNode: Equatable {
    let name: String
    var children: [DeclNode]

    var enumDecl: Decl {
        return BlockTypeDecl.enum(
            typeName: name,
            conformances: nil,
            children.map { $0.enumDecl }
        )
    }
}

func namespaceDecls(for routes: [ResolvedRoute]) -> [DeclNode] {
    var paths = [DeclNode]()
    for path in routes.map(\.path) {
        var remainingPath = path.components.makeIterator()

        func fillFrom(currentNode: inout DeclNode) {
            guard let next = remainingPath.next().map(swiftTypeName) else {
                return
            }
            var newNode = DeclNode(name: next, children: [])
            fillFrom(currentNode: &newNode)

            currentNode.children.append(newNode)
        }

        func step(currentNodes: inout [DeclNode]) {

            guard let next = remainingPath.next().map(swiftTypeName) else {
                return
            }

            if let idx = currentNodes.firstIndex(where: { $0.name == next }) {
                step(currentNodes: &currentNodes[idx].children)
            } else {
                var newNode = DeclNode(name: next, children: [])
                fillFrom(currentNode: &newNode)
                currentNodes.append(newNode)
            }
        }

        step(currentNodes: &paths)
    }
    return paths
}

func documents(
    for endpoint: ResolvedEndpoint,
    on server: OpenAPI.Server,
    testSuiteConfiguration: TestSuiteConfiguration,
    logger: Logger?
) -> [OpenAPI.Response.StatusCode: DataDocumentSwiftGen] {
    var responseDocuments = [OpenAPI.Response.StatusCode: DataDocumentSwiftGen]()
    for (statusCode, response) in endpoint.responses {

        let contextString = "Parsing the HTTP \(statusCode.rawValue) response document for the \(endpoint.method.rawValue) endpoint"

        guard let jsonResponse = response.content[.json] else {
            if response.content.isEmpty && ((statusCode == 200 && endpoint.method == .get) || (statusCode == 201 && endpoint.method == .post)) {
                logger?.warning(
                    path: endpoint.path.rawValue,
                    context: contextString,
                    message: "No response content found but endpoints of this type would generally have some form of response body."
                )
            } else {
                let alternativesString = response.content.count > 0
                    ? "Did find content with types: \(response.content.keys.map(\.rawValue))."
                    : "No content options of any type found."
                logger?.info(
                    path: endpoint.path.rawValue,
                    context: contextString,
                    message: "Skipping response because no 'application/json' content found. \(alternativesString)"
                )
            }
            continue
        }

        let responseSchema = jsonResponse.schema

        guard case .object = responseSchema else {
            logger?.warning(
                path: endpoint.path.rawValue,
                context: contextString,
                message: "Found non-object response schema root (expected JSON:API 'data' object). Skipping '\(String(describing: responseSchema.jsonTypeFormat?.jsonType))'."
            )
            continue
        }

        let responseBodyTypeName = "Document_\(statusCode.rawValue)"
        let examplePropName = "example_\(statusCode.rawValue)"

        let example: ExampleSwiftGen?
        do {
            example = try jsonResponse.example.map { try ExampleSwiftGen.init(openAPIExample: $0, propertyName: examplePropName) }
        } catch let err {
            logger?.warning(
                path: endpoint.path.rawValue,
                context: contextString,
                message: String(describing: err)
            )
            example = nil
        }

        let testExampleFuncs: [TestFunctionGenerator]
        do {
            testExampleFuncs = try exampleTests(
                testSuiteConfiguration: testSuiteConfiguration,
                server: server,
                pathComponents: endpoint.path,
                parameters: endpoint.parameters,
                jsonResponse: jsonResponse,
                exampleDataPropName: example.map { _ in examplePropName },
                bodyType: .init(.init(name: responseBodyTypeName)),
                expectedHttpStatus: statusCode
            )
        } catch let err as ExampleTestGenError {
            switch err {
            case .incorrectTestParameterFormat:
                logger?.warning(
                    path: endpoint.path.rawValue,
                    context: contextString,
                    message: "Found x-tests with parameters but it was not a dictionary with String keys and String values like expected. Non-String parameter values still need to be encoded as Strings in the x-tests dictionary."
                )
            }

            testExampleFuncs = []
        } catch let err {
            logger?.warning(
                path: endpoint.path.rawValue,
                context: contextString,
                message: String(describing: err)
            )

            testExampleFuncs = []
        }

        do {
            responseDocuments[statusCode] = try DataDocumentSwiftGen(
                swiftTypeName: responseBodyTypeName,
                structure: responseSchema,
                allowPlaceholders: false,
                example: example,
                testExampleFuncs: testExampleFuncs
            )
        } catch let err {
            logger?.warning(
                path: endpoint.path.rawValue,
                context: contextString,
                message: String(describing: err)
            )
            continue
        }
    }
    return responseDocuments
}

func document(
    from request: DereferencedRequest,
    for httpVerb: HttpMethod,
    at path: OpenAPI.Path,
    logger: Logger?
) throws -> DataDocumentSwiftGen? {

    guard let jsonRequest = request.content[.json] else {
        return nil
    }

    let requestSchema = jsonRequest.schema

    guard case .object = requestSchema else {
        logger?.warning(
            path: path.rawValue,
            context: "Parsing the request document",
            message: "Found non-object request schema root (expected JSON:API 'data' object). Skipping \(String(describing: requestSchema.jsonTypeFormat?.jsonType))"
        )
        return nil
    }

    let requestBodyTypeName = "Document"
    let examplePropName = "example"

    let example: ExampleSwiftGen?
    do {
        example = try jsonRequest.example.map { try ExampleSwiftGen.init(openAPIExample: $0, propertyName: examplePropName) }
    } catch let err {
        logger?.warning(
            path: path.rawValue,
            context: "Parsing the request document for the \(httpVerb.rawValue) endpoint",
            message: String(describing: err)
        )
        example = nil
    }

    let testExampleFuncs: [TestFunctionGenerator]
    do {
        testExampleFuncs = try example.map { _ in
            try [
                exampleParsingTest(
                    exampleDataPropName: examplePropName,
                    bodyType: .init(.init(name: requestBodyTypeName)),
                    expectedHttpStatus: nil
                )
            ]
        } ?? []
    } catch let err {
        logger?.warning(
            path: path.rawValue,
            context: "Parsing the request document for the \(httpVerb.rawValue) endpoint",
            message: String(describing: err)
        )

        testExampleFuncs = []
    }

    return try DataDocumentSwiftGen(
        swiftTypeName: requestBodyTypeName,
        structure: requestSchema,
        allowPlaceholders: false,
        example: example,
        testExampleFuncs: testExampleFuncs
    )
}

func exampleTests(
    testSuiteConfiguration: TestSuiteConfiguration,
    server: OpenAPI.Server,
    pathComponents: OpenAPI.Path,
    parameters: [DereferencedParameter],
    jsonResponse: DereferencedContent,
    exampleDataPropName: String?,
    bodyType: SwiftTypeRep,
    expectedHttpStatus: OpenAPI.Response.StatusCode
) throws -> [TestFunctionGenerator] {
    // if we have an x-tests extension, use it. otherwise, fall
    // back to a test that just parses any given example.
    guard let testsExtension = jsonResponse.vendorExtensions["x-tests"]?.value as? [String: Any] else {
        return try exampleDataPropName.map {
            try [
                exampleParsingTest(
                    exampleDataPropName: $0,
                    bodyType: bodyType,
                    expectedHttpStatus: expectedHttpStatus
                )
            ]
        } ?? []
    }

    return try OpenAPIExampleRequestTestSwiftGen.TestProperties
        .properties(for: testsExtension, server: server)
        .compactMap { properties in
            do {
                return try OpenAPIExampleRequestTestSwiftGen(
                    server: server,
                    pathComponents: pathComponents,
                    parameters: parameters,
                    testSuiteConfiguration: testSuiteConfiguration,
                    testProperties: properties,
                    exampleResponseDataPropName: exampleDataPropName,
                    responseBodyType: bodyType,
                    expectedHttpStatus: expectedHttpStatus
                )
            } catch let error as OpenAPIExampleRequestTestSwiftGen.Error {
                if case .valueMissingForParameter = error, properties.ignoreMissingParameterWarnings {
                    return nil
                }
                throw error
            }
    }
}

/// Create a test function generator that attempts to parse an
/// example under the schema for the given request or response
/// body.
func exampleParsingTest(
    exampleDataPropName: String,
    bodyType: SwiftTypeRep,
    expectedHttpStatus: OpenAPI.Response.StatusCode?
) throws -> TestFunctionGenerator {
    return try OpenAPIExampleParseTestSwiftGen(
        exampleDataPropName: exampleDataPropName,
        bodyType: bodyType,
        exampleHttpStatusCode: expectedHttpStatus
    )
}

enum ExampleTestGenError: Swift.Error {
    case incorrectTestParameterFormat
}

let packageFile: String = """
// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "GeneratedAPITests",
    products: [
        .library(name: "generated-api", targets: ["GeneratedAPI"])
    ],
    dependencies: [
        .package(url: "https://github.com/Flight-School/AnyCodable.git", .upToNextMinor(from: "0.2.2")),
        .package(url: "https://github.com/mattpolzin/JSONAPI.git", .upToNextMajor(from: "4.0.0"))
    ],
    targets: [
        .target(
            name: "GeneratedAPI",
            dependencies: ["JSONAPI", "JSONAPITesting", "AnyCodable"]
        ),
        .testTarget(
            name: "GeneratedAPITests",
            dependencies: ["JSONAPI", "JSONAPITesting", "AnyCodable"]
        )
    ]
)
"""

let linuxMainFile: String = """
import XCTest

import GeneratedAPITests

XCTMain([
    testCase(GeneratedTests.allTests)
])
"""
