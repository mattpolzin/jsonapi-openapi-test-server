
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
            jsonEncoder.outputFormatting = .sortedKeys
        }
        #if os(Linux)
            jsonEncoder.dateEncodingStrategy = .iso8601
            jsonEncoder.outputFormatting = .sortedKeys
        #endif

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
####"""
`jsonapi-openapi-test-server` is a Test Server that generates and runs tests based on OpenAPI documentation for JSON:API compliant endpoints.

## Parsing Warnings
1. Non-JSON:API-compliant request/response schemas.
2. Response defined to allow includes but the specific types of includes are not specified.

## Parsing Errors
1. A documented example cannot be parsed using the given schema for an API endpoint.

## Response Errors
You can add annotations to your OpenAPI that instruct the Test Server to make requests and check that the response fits the documented schema or even that the response exactly matches a particular example.

### Response Test Configuration
You specify test parameters under an `x-tests` specification extension on the OpenAPI Media Type Object within a Response Object (e.g. `responses/'200'/content/'application/json'/x-tests`). `x-tests` has the following structure:
```json
{
    "test_name": {
        "test_host": "url", (optional, if omitted then default server for API will be used.
        "skip_example": true | false, (optional, defaults to false)
        "parameters": {
            "path_param_name": "value",
            "header_param_name": "value" (must be a string, even if the parameter type is Int or other)
        },
        "query_parameters": [
            {
                "name": "param_name",
                "value": "param_value"
            }
        ]
    }
}
```

Entries in the `parameters` dictionary are mapped to header/path parameters by the names used in the OpenAPI documentation.

Entries in the `query_parameters` array must be objects with `name` and `value` entries corresponding to the name and value of the query parameter (already encoded for use in a URL). This structure is necessitated by the fact that the same query parameter name can be repeated for "exploded" query parameter objects.

"""####
}
