//
//  Post.swift
//  remote-content-view-Example
//
//  Created by mybkhn on 2021/05/31.
//

import Foundation

struct Post : Codable {

	var id: Int

	var title: String

	var body: String
}

final class PostsStore {

	enum PostsError : Error {

		case empty
	}

	func fetchPosts(_ completion: @escaping (_ result: Result<[Post], Error>) -> Void) -> AnyObject {
		let url = URL(string: "https://jsonplaceholder.typicode.com/posts")!
		let task = URLSession.shared.dataTask(with: url) { data, response, networkError in
			if let networkError = networkError {
				completion(.failure(networkError))
				return
			}

			if let data = data {
				let decoder = JSONDecoder()

				do {
					let posts = try decoder.decode([Post].self, from: data)
					completion(.success(posts))
				}
				catch {
					completion(.failure(error))
				}

				return
			}

			completion(.failure(PostsError.empty))
		}

		task.resume()

		return task
	}
}
