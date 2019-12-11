//
//  QueryBuilder+FirstOrCreate.swift
//  App
//
//  Created by Mathew Polzin on 12/9/19.
//

import FluentKit

fileprivate struct NotFoundError: Error {}

extension QueryBuilder {

    /// Retrieve the first result matching the current query or create a new record
    /// if no results are found.
    ///
    /// - Important: This operation is **not** atomic.
    ///
    /// Example:
    ///
    ///     User.query(on: database)
    ///         .filter(\.$name == "Jon")
    ///         .first(orCreate: User(name: "Jon"))
    ///
    public func first(
        orCreate newModel: @escaping @autoclosure () -> Model
    ) -> EventLoopFuture<Model> {

        self.first().flatMap { existingModel in
            guard let res = existingModel else {
                let model = newModel()
                return model.create(on: self.database).map { model }
            }
            return self.database.eventLoop.makeSucceededFuture(res)
        }
    }
}
