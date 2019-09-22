import Vapor

/// Register your application's routes here.
public func routes(in container: Container) throws -> Routes {

    let routes = Routes(eventLoop: container.eventLoop)

    // Basic "It works" example
    routes.get { req in
        return "It works!"
    }
    
    // Basic "Hello, world!" example
    routes.get("hello") { req in
        return "Hello, world!"
    }

    // Example of configuring a controller
//    let todoController = TodoController()
//    router.get("todos", use: todoController.index)
//    router.post("todos", use: todoController.create)
//    router.delete("todos", Todo.parameter, use: todoController.delete)

    return routes
}
