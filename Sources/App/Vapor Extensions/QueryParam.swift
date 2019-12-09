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
}

public protocol QueryParamProtocol: AbstractQueryParam {
    associatedtype SwiftType
}

public struct QueryParam<T: Decodable>: QueryParamProtocol {
    public typealias SwiftType = T

    public let name: String
    public let allowedValues: [String]?
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.allowedValues = nil
        self.description = description
    }

    public init<U: LosslessStringConvertible>(name: String, description: String? = nil, allowedValues: [U]) {
        self.name = name
        self.description = description
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
/// e.x. (`.csv(.string)`)
///
///     <path>?param=hello,world
public typealias CSVQueryParam<SwiftType: Decodable> = QueryParam<[SwiftType]>

/// A dictionary of values.
///
/// You can specify the keys that should be allowed in the dictionary or leave
/// that `nil` to allow any key.
///
/// e.x.
///
///     <path>?param[hello]=hi+there
public struct DictQueryParam<SwiftType: Decodable>: QueryParamProtocol {
    public let name: String
    public let description: String?
    public let allowedKeys: [String]?
    public let allowedValues: [String]?

    public init(name: String, description: String? = nil, allowedKeys: [String]? = nil) {
        self.name = name
        self.description = description
        self.allowedKeys = allowedKeys
        self.allowedValues = nil
    }
}

//public enum QueryParameterType {
//    /// A single value
//    ///
//    /// e.x.
//    ///
//    ///     <path>?param=hello
//    case string
//
//    /// A single value (must be integer)
//    ///
//    /// e.x.
//    ///
//    ///     <path>?param=1
//    case integer
//
//    /// A single value (must be number, not necessarily an integer)
//    ///
//    /// e.x.
//    ///
//    ///     <path>?param=10.345
//    case number
//
//    /// A comma separated list of values
//    ///
//    /// e.x. (`.csv(.string)`)
//    ///
//    ///     <path>?param=hello,world
//    indirect case csv(ParameterType)
//
//    /// A dictionary of values.
//    ///
//    /// You can specify the keys that should be allowed in the dictionary or leave
//    /// that `nil` to allow any key.
//    ///
//    /// e.x.
//    ///
//    ///     <path>?param[hello]=hi+there
//    indirect case dict(allowedKeys: [String]?, ParameterType)
//}
