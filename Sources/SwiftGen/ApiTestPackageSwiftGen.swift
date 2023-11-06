//
//  ApiTestPackageSwiftGen.swift
//
//
//  Created by Mathew Polzin on 7/27/19.
//

import Foundation
import OpenAPIKit30
import JSONAPISwiftGen
import ZIPFoundation

public protocol Logger {
    func error(path: String?, context: String, message: String)
    func warning(path: String?, context: String, message: String)
    func success(path: String?, context: String, message: String)
    func info(path: String?, context: String, message: String)

    var errorCount: Int { get }
    var warningCount: Int { get }
    var successCount: Int { get }
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
        Import.Poly as Decl,
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
            requestDocument: DocumentSwiftGenerator?,
            responseDocuments: [OpenAPI.Response.StatusCode : DocumentSwiftGenerator],
            testFunctionNames: [TestFunctionName]
        )
    ]
    results = routes.flatMap(\.endpoints).map { endpoint in

        let documentFileNameString = documentTypeName(path: endpoint.path, verb: endpoint.method)


        let apiRequestTest: APIRequestTestSwiftGen?
        do {
            apiRequestTest = try APIRequestTestSwiftGen(
                method: endpoint.method,
                server: server,
                pathComponents: endpoint.path,
                parameters: endpoint.parameters
            )
        } catch let error as APIRequestTestSwiftGen.Error {
            if case .pathParametersNotDefined(names: let names) = error {
                let namesString = names.joined(separator: ", ")
                logger?.warning(
                    path: endpoint.path.rawValue,
                    context: "Processing the \(endpoint.method.rawValue) endpoint",
                    message: "Some path parameters (\(namesString)) were not defined for this endpoint"
                )
            }
            apiRequestTest = nil
        } catch {
            // we will just ignore other errors for now
            apiRequestTest = nil
        }

        let responseDocuments = documents(
            for: endpoint,
            on: server,
            testSuiteConfiguration: testSuiteConfiguration,
            logger: logger
        )

        let requestDocument: DocumentSwiftGenerator?
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
        } catch let error {
            logger?.warning(
                path: endpoint.path.rawValue,
                context: "Parsing request document for \(endpoint.method.rawValue)",
                message: String(describing: error)
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
        context: "Processing OpenAPI Document",
        message: "Created \(totalTestCases) test cases across \(totalEndpointCount) endpoints mounted at \(totalRouteCount) routes. [Warnings: \(logger?.warningCount ?? 0), Errors: \(logger?.errorCount ?? 0)]"
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
        .map(TestFunctionName.swiftName)
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
) throws where T.Element == DocumentSwiftGenerator {
    for document in documents {

        guard let jsonAPIDocument = document as? JSONAPIDocumentSwiftGen else {
            continue
        }

        let resourceObjectGenerators = jsonAPIDocument.resourceObjectGenerators

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
    requestDoc: DocumentSwiftGenerator?,
    responseDocs: T,
    httpVerb: HttpMethod
) -> Decl where T.Element == DocumentSwiftGenerator {
    let requestDocAndExample = requestDoc.map { doc in
        doc.decls
            + doc.exampleGenerators.flatMap { $0.decls }
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
            + doc.exampleGenerators.flatMap { $0.decls }
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
    reqDoc: DocumentSwiftGenerator?,
    respDocs: T,
    httpVerb: HttpMethod,
    extending namespace: String,
    formatGeneratedSwift: Bool = true
) throws where T.Element == DocumentSwiftGenerator {

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
        Import.Poly as Decl,
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
                Import.Poly,
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
            guard let next = remainingPath.next().map(TestFunctionName.swiftName) else {
                return
            }
            var newNode = DeclNode(name: next, children: [])
            fillFrom(currentNode: &newNode)

            currentNode.children.append(newNode)
        }

        func step(currentNodes: inout [DeclNode]) {

            guard let next = remainingPath.next().map(TestFunctionName.swiftName) else {
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
) -> [OpenAPI.Response.StatusCode: DocumentSwiftGenerator] {
    var responseDocuments = [OpenAPI.Response.StatusCode: DocumentSwiftGenerator]()
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

        guard let responseSchema = jsonResponse.schema else {
            // skip if there is no schema to work with
            continue
        }

        let simplifiedResponseSchema: DereferencedJSONSchema
        do {
            simplifiedResponseSchema = try responseSchema.simplified()
        } catch let error {
            logger?.warning(
                path: endpoint.path.rawValue,
                context: contextString,
                message: String(describing: error)
            )
            continue
        }

        let expectJSONAPISchema = jsonResponse.vendorExtensions["x-not-json-api"]?.value as? Bool != true

        let responseBodyTypeName = "Document_\(statusCode.rawValue)"
        func exampleProp(named name: String) -> String {
            let validName = name.replacingOccurrences(of: " ", with: "_")
            return "example_\(statusCode.rawValue)_\(validName)"
        }

        // names and generators
        let exampleGens: [(String, ExampleSwiftGen)]

        if let examples = jsonResponse.examples {
            exampleGens = examples
                .compactMapValues { $0.value?.b }
                .compactMap { (name, example) in
                    do {
                        return (name, try ExampleSwiftGen.init(openAPIExample: example, propertyName: exampleProp(named: name)))
                    } catch let err {
                        logger?.warning(
                            path: endpoint.path.rawValue,
                            context: contextString,
                            message: String(describing: err)
                        )
                        return nil
                    }
                }
        } else if let example = jsonResponse.example {
            do {
                exampleGens = [ ("default", try ExampleSwiftGen.init(openAPIExample: example, propertyName: exampleProp(named: "default"))) ]
            } catch let err {
                logger?.warning(
                    path: endpoint.path.rawValue,
                    context: contextString,
                    message: String(describing: err)
                )
                exampleGens = []
            }
        } else {
            exampleGens = []
        }

        // TODO: support x-tests for named examples. Right now it just assumes there
        //       is only 1 example.
        let testExampleFuncs: [TestFunctionGenerator]
        do {
            testExampleFuncs = try exampleTests(
                testSuiteConfiguration: testSuiteConfiguration,
                server: server,
                method: endpoint.method,
                pathComponents: endpoint.path,
                parameters: endpoint.parameters,
                jsonResponse: jsonResponse,
                exampleDataPropNames: exampleGens.map { (name: $0.0, propName: $0.1.propertyName) },
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
            responseDocuments[statusCode] = try documentGenerator(
                expectJSONAPISchema: expectJSONAPISchema,
                swiftTypeName: responseBodyTypeName,
                structure: simplifiedResponseSchema,
                examples: exampleGens.map { $0.1 },
                testExampleFuncs: testExampleFuncs,
                path: endpoint.path,
                context: contextString,
                logger: logger
            )
        } catch let error {
            logger?.warning(
                path: endpoint.path.rawValue,
                context: contextString,
                message: String(describing: error)
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
) throws -> DocumentSwiftGenerator? {

    guard let jsonRequest = request.content[.json] else {
        return nil
    }

    guard let requestSchema = jsonRequest.schema else {
        // skip if there is no schema to work with
        return nil
    }

    let contextString = "Parsing the request document for the \(httpVerb.rawValue) endpoint"

    let simplifiedRequestSchema: DereferencedJSONSchema
    do {
        simplifiedRequestSchema = try requestSchema.simplified()
    } catch let error {
        logger?.warning(
            path: path.rawValue,
            context: contextString,
            message: String(describing: error)
        )
        return nil
    }

    let expectJSONAPISchema = jsonRequest.vendorExtensions["x-not-json-api"]?.value as? Bool != true

    let requestBodyTypeName = "Document"
    func exampleProp(named name: String) -> String {
        let validName = name.replacingOccurrences(of: " ", with: "_")
        return "example_request_\(validName)"
    }

    let exampleGens: [ExampleSwiftGen]

    if let examples = jsonRequest.examples {
        exampleGens = examples
            .compactMapValues { $0.value?.b }
            .compactMap { (name, example) in
                do {
                    return try ExampleSwiftGen.init(openAPIExample: example, propertyName: exampleProp(named: name))
                } catch let err {
                    logger?.warning(
                        path: path.rawValue,
                        context: contextString,
                        message: String(describing: err)
                    )
                    return nil
                }
            }
    } else if let example = jsonRequest.example {
        do {
            exampleGens = [ try ExampleSwiftGen.init(openAPIExample: example, propertyName: exampleProp(named: "default")) ]
        } catch let err {
            logger?.warning(
                path: path.rawValue,
                context: contextString,
                message: String(describing: err)
            )
            exampleGens = []
        }
    } else {
        exampleGens = []
    }

    // TODO: support multiple request body example parse tests.
    let testExampleFuncs: [TestFunctionGenerator]
    do {
        testExampleFuncs = try exampleGens.first.map { gen in
            try [
                exampleParsingTest(
                    exampleDataPropName: gen.propertyName,
                    bodyType: .init(.init(name: requestBodyTypeName)),
                    expectedHttpStatus: nil,
                    exampleName: "default"
                )
            ]
        } ?? []
    } catch let err {
        logger?.warning(
            path: path.rawValue,
            context: contextString,
            message: String(describing: err)
        )

        testExampleFuncs = []
    }

    return try documentGenerator(
        expectJSONAPISchema: expectJSONAPISchema,
        swiftTypeName: requestBodyTypeName,
        structure: simplifiedRequestSchema,
        examples: exampleGens,
        testExampleFuncs: testExampleFuncs,
        path: path,
        context: contextString,
        logger: logger
    )
}

/// Create a document swift generator by attempting to
/// treat the given schema as JSON:API or not depending
/// on the value passed as `expectJSONAPISchema`.
///
/// This will only attempt to create a document based on
/// the JSON:API specification of `expectJSONAPISchema`
/// is `true`, but it will attempt to create a document based
/// on generic JSON structures regardless of whether it has
/// just failed to create a document based on JSON:API (i.e.
/// as a fallback) or it was told to not expect JSON:API to
/// begin with.
func documentGenerator(
    expectJSONAPISchema: Bool,
    swiftTypeName: String,
    structure: DereferencedJSONSchema,
    examples: [ExampleSwiftGen],
    testExampleFuncs: [TestFunctionGenerator],
    path: OpenAPI.Path,
    context contextString: String,
    logger: Logger?
) throws -> DocumentSwiftGenerator {
    if expectJSONAPISchema {
        do {
            return try JSONAPIDocumentSwiftGen(
                swiftTypeName: swiftTypeName,
                structure: structure,
                allowPlaceholders: false,
                examples: examples,
                testExampleFuncs: testExampleFuncs
            )
        } catch let error {
            logger?.warning(
                path: path.rawValue,
                context: contextString,
                message: String(describing: error)
            )
        }
    }
    return try StructDocumentSwiftGen(
        swiftTypeName: swiftTypeName,
        structure: structure,
        allowPlaceholders: false,
        examples: examples,
        testExampleFuncs: testExampleFuncs
    )
}

func exampleTests(
    testSuiteConfiguration: TestSuiteConfiguration,
    server: OpenAPI.Server,
    method: OpenAPI.HttpMethod,
    pathComponents: OpenAPI.Path,
    parameters: [DereferencedParameter],
    jsonResponse: DereferencedContent,
    exampleDataPropNames: [(name: String, propName: String)],
    bodyType: SwiftTypeRep,
    expectedHttpStatus: OpenAPI.Response.StatusCode
) throws -> [TestFunctionGenerator] {
    // if we have an x-tests extension, use it. otherwise, fall
    // back to a test that just parses any given example.
    guard let testsExtension = jsonResponse.vendorExtensions["x-tests"]?.value as? [String: Any] else {
        return try exampleDataPropNames.map {
            try
                exampleParsingTest(
                    exampleDataPropName: $0.propName,
                    bodyType: bodyType,
                    expectedHttpStatus: expectedHttpStatus,
                    exampleName: $0.name
                )
        }
    }

    // TODO: handle tests against named examples.
    return try OpenAPIExampleRequestTestSwiftGen.TestProperties
        .properties(for: testsExtension, server: server)
        .compactMap { properties in
            do {
                return try OpenAPIExampleRequestTestSwiftGen(
                    method: method,
                    server: server,
                    pathComponents: pathComponents,
                    parameters: parameters,
                    testSuiteConfiguration: testSuiteConfiguration,
                    testProperties: properties,
                    exampleResponseDataPropName: exampleDataPropNames.first?.propName,
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
    expectedHttpStatus: OpenAPI.Response.StatusCode?,
    exampleName: String
) throws -> TestFunctionGenerator {
    return try OpenAPIExampleParseTestSwiftGen(
        exampleDataPropName: exampleDataPropName,
        bodyType: bodyType,
        exampleHttpStatusCode: expectedHttpStatus,
        exampleName: exampleName
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
        .package(url: "https://github.com/mattpolzin/JSONAPI.git", .upToNextMajor(from: "5.1.0")),
        .package(url: "https://github.com/mattpolzin/Poly.git", .upToNextMajor(from: "2.6.0"))
    ],
    targets: [
        .target(
            name: "GeneratedAPI",
            dependencies: ["JSONAPI", "JSONAPITesting", "AnyCodable", "Poly"]
        ),
        .testTarget(
            name: "GeneratedAPITests",
            dependencies: ["JSONAPI", "JSONAPITesting", "AnyCodable", "Poly"]
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
