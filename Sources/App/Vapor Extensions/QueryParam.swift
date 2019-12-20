//
//  QueryContext.swift
//  App
//
//  Created by Mathew Polzin on 12/8/19.
//

import Vapor

public protocol AbstractQueryParam {
    var name: String { get }
    var allowedValues: [String]? { get }
    var description: String? { get }

    var swiftType: Any.Type { get }
}

public protocol QueryParamProtocol: AbstractQueryParam {
    associatedtype SwiftType

    var defaultValue: SwiftType? { get }
}

extension QueryParamProtocol {
    public var swiftType: Any.Type {
        return SwiftType.self
    }
}

public struct QueryParam<T: Decodable>: QueryParamProtocol {
    public typealias SwiftType = T

    public let name: String
    public let allowedValues: [String]?
    public let description: String?
    public let defaultValue: T?

    public init(name: String, description: String? = nil, defaultValue: T? = nil) {
        self.name = name
        self.allowedValues = nil
        self.defaultValue = defaultValue
        self.description = description
    }

    public init<U: LosslessStringConvertible>(name: String, description: String? = nil, defaultValue: T? = nil, allowedValues: [U]) {
        self.name = name
        self.description = description
        self.defaultValue = defaultValue
        self.allowedValues = allowedValues.map(String.init(describing:))
    }
}

/// A single value
///
/// e.x.
///
///     <path>?param=hello
public typealias StringQueryParam = QueryParam<String>

/// A single value (must be integer)
///
/// e.x.
///
///     <path>?param=1
public typealias IntegerQueryParam = QueryParam<Int>

/// A single value (must be number, not necessarily an integer)
///
/// e.x.
///
///     <path>?param=10.345
public typealias NumberQueryParam = QueryParam<Double>

/// A comma separated list of values
///
/// e.x. (`CSVQueryParam<String>`)
///
///     <path>?param=hello,world
public typealias CSVQueryParam<SwiftType: Decodable> = QueryParam<[SwiftType]>

/// A value nested in an object.
///
/// e.x.
///
///     <path>?param[hello]=hi+there
///
/// In this example, the path would be `["param", "hello"]`
public struct NestedQueryParam<SwiftType: Decodable>: QueryParamProtocol {
    public let path: [String]
    public let allowedValues: [String]?
    public let description: String?
    public let defaultValue: SwiftType?

    public var name: String { path[0] }

    public init(path: String..., description: String? = nil, defaultValue: SwiftType? = nil, allowedValues: [String]? = nil) {
        self.init(path: path, description: description, defaultValue: defaultValue, allowedValues: allowedValues)
    }

    public init(path: [String], description: String? = nil, defaultValue: SwiftType? = nil, allowedValues: [String]? = nil) {
        self.path = path
        self.allowedValues = allowedValues
        self.description = description
        self.defaultValue = defaultValue
    }
}
