//
//  defaults.swift
//  
//
//  Created by Mathew Polzin on 5/7/20.
//

import Vapor
import Yams

extension YAMLDecoder: ContentDecoder {
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D where D : Decodable {
        return try self.decode(from: body.getString(at: body.readerIndex, length: body.readableBytes, encoding: .utf8) ?? "")
    }
}

public func configureDefaults(for app: Application) throws {
    // MARK: JSON
    ContentConfiguration.global.use(decoder: JSONDecoder.custom(dates: .iso8601), for: .jsonAPI)

    // MARK: YAML
    ContentConfiguration.global.use(decoder: YAMLDecoder(), for: .init(type: "application", subType: "x-yaml"))
    ContentConfiguration.global.use(decoder: YAMLDecoder(), for: .init(type: "text", subType: "yaml"))
    ContentConfiguration.global.use(decoder: YAMLDecoder(), for: .init(type: "text", subType: "vnd.yaml"))
}
