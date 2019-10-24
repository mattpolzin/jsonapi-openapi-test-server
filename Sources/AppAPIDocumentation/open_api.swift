
import Vapor
import App
import Foundation
import OpenAPIKit
import JSONAPIOpenAPI

public struct OpenAPIDocs {

    public let document: OpenAPI.Document

    public init(contentConfig: ContentConfiguration, routes: Routes) throws {

        // TODO: Add support for ContentEncoder to JSONAPIOpenAPI
        let jsonEncoder = JSONEncoder()
        if #available(macOS 10.12, *) {
            jsonEncoder.dateEncodingStrategy = .iso8601
        }

        let info = OpenAPI.Document.Info(
            title: "OpenAPI Test Server API",
            description: Self.description,
            version: "1.0"
        )

        // TODO: get hostname & port from environment
        let servers = [
            OpenAPI.Server(url: URL(string: "http://localhost")!)
        ]

        let components = OpenAPI.Components(
            schemas: [:],
            responses: [:],
            parameters: [:],
            examples: [:],
            requestBodies: [:],
            headers: [:]
        )

        let paths = try routes.openAPIPathItems(using: jsonEncoder)

        document = OpenAPI.Document(
            info: info,
            servers: servers,
            paths: paths,
            components: components
        )
    }

    private static let description =
###"""
`jsonapi-openapi-test-server` is a Test Server that generates and runs tests based on OpenAPI documentation for JSON:API compliant endpoints.
"""###
}
