//
//  TestProgressTracker.swift
//  APITesting
//
//  Created by Mathew Polzin on 12/8/19.
//

import FluentKit

public protocol TestProgressTracker {
    associatedtype Persister

    func markPending() -> Self

    func markBuilding() -> Self

    func markRunning() -> Self

    func markPassed() -> Self

    func markFailed() -> Self

    func save(on: Persister) -> EventLoopFuture<Void>
}

public enum NullTracker: TestProgressTracker {
    public func markPending() -> Self { fatalError() }

    public func markBuilding() -> Self { fatalError() }

    public func markRunning() -> Self { fatalError() }

    public func markPassed() -> Self { fatalError() }

    public func markFailed() -> Self { fatalError() }

    public func save(on: Never) -> EventLoopFuture<Void> {}
}
