//
//  TestHelpers.swift
//  
//
//  Created by Mathew Polzin on 5/2/20.
//

import Fluent
import XCTFluent

extension TestOutput {
    public init<TestModel: Model>(_ model: TestModel) {

        func unpack(_ dbValue: DatabaseQuery.Value) -> Any? {
            switch dbValue {
            case .null:
                return nil
            case .enumCase(let value):
                return value
            case .custom(let value):
                return value
            case .bind(let value):
                return value
            case .array(let array):
                return array.map(unpack)
            case .dictionary(let dictionary):
                return dictionary.mapValues(unpack)
            case .default:
                return "" as Any
            }
        }

        self.init(
            model.input.values.mapValues(unpack)
        )
    }
}
