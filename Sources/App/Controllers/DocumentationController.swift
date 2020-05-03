//
//  DocumentationController.swift
//  App
//
//  Created by Mathew Polzin on 12/6/19.
//

import Vapor

final class DocumentationController {

    static func show(_ req: Request) -> Response {
        let response = Response(
            body:
"""
<!DOCTYPE html>
<html>
  <head>
    <title>ReDoc</title>
    <!-- needed for adaptive design -->
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://fonts.googleapis.com/css?family=Montserrat:300,400,700|Roboto:300,400,700" rel="stylesheet">

    <!--
    ReDoc doesn't change outer page styles
    -->
    <style>
      body {
        margin: 0;
        padding: 0;
      }
    </style>
  </head>
  <body>
    <redoc spec-url='/openapi.yml'></redoc>
    <script src="https://cdn.jsdelivr.net/npm/redoc@next/bundles/redoc.standalone.js"> </script>
  </body>
</html>
"""
        )

        response.headers.contentType = .html

        return response
    }
}

extension DocumentationController {
    public static func mount(on app: Application, at rootPath: RoutingKit.PathComponent...) {
        app.on(.GET, rootPath, use: Self.show)
            .tags("Documentation")
            .summary("Show Documentation")
    }
}
