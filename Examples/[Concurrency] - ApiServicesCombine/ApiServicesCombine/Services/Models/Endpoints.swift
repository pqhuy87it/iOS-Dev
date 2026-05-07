import Foundation

// === Endpoint definitions ===

enum Endpoints {
    static let baseURL = "https://jsonplaceholder.typicode.com"
    
    static func users() -> Endpoint {
        Endpoint(path: "/users")
    }
    
    static func user(id: Int) -> Endpoint {
        Endpoint(path: "/users/\(id)")
    }
    
    static func posts(page: Int = 1, limit: Int = 20) -> Endpoint {
        Endpoint(
            path: "/posts",
            queryItems: [
                URLQueryItem(name: "_page", value: "\(page)"),
                URLQueryItem(name: "_limit", value: "\(limit)"),
            ]
        )
    }
    
    static func post(id: Int) -> Endpoint {
        Endpoint(path: "/posts/\(id)")
    }
    
    static func createPost(_ request: CreatePostRequest) -> Endpoint {
        Endpoint(path: "/posts", method: .POST, body: request)
    }
    
    static func updatePost(id: Int, _ request: CreatePostRequest) -> Endpoint {
        Endpoint(path: "/posts/\(id)", method: .PUT, body: request)
    }
    
    static func deletePost(id: Int) -> Endpoint {
        Endpoint(path: "/posts/\(id)", method: .DELETE)
    }
    
    static func userPosts(userId: Int) -> Endpoint {
        Endpoint(
            path: "/posts",
            queryItems: [URLQueryItem(name: "userId", value: "\(userId)")]
        )
    }
}
