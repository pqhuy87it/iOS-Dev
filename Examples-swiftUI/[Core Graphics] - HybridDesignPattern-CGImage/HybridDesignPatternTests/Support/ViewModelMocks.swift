import Foundation
import UIKit
import XCTest
@testable import HybridDesignPattern

// MARK: - Domain entity fixtures (main-actor because the entity is isolated from the main-actor)

@MainActor
enum EntityFixtures {
    static func photos(ids: [String]) -> [Photo] {
        DTOFixtures.photos(ids: ids).map { $0.toDomain() }
    }

    static func topics(_ topics: [(id: String, slug: String)]) -> [Topic] {
        DTOFixtures.topics(topics).map { $0.toDomain() }
    }

    static func searchResult(total: Int, totalPages: Int, photoIDs: [String]) -> SearchResult {
        DTOFixtures.searchResult(total: total, totalPages: totalPages, photoIDs: photoIDs).toDomain()
    }
}

// MARK: - Loadable test helpers

extension Loadable {
    var isLoadingCase: Bool { if case .isLoading = self { return true }; return false }
    var isNotRequestedCase: Bool { if case .notRequested = self { return true }; return false }
    /// Đã xong (loaded hoặc failed), không còn notRequested/isLoading-lần-đầu.
    var isSettled: Bool { value != nil || error != nil }
}

// Wait for state to update (send() spawn Task fire-and-forget)
@MainActor
func waitUntil(
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() >= deadline {
            XCTFail("waitUntil timed out", file: file, line: line)
            return
        }
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
    }
}

// MARK: - Mock interactors

final class MockPhotosInteractor: PhotosInteractorProtocol {
    var handler: (Int, Int) async throws -> [Photo] = { _, _ in [] }
    private(set) var callCount = 0
    private(set) var requestedPages: [Int] = []

    func fetchPhotos(page: Int, perPage: Int) async throws -> [Photo] {
        callCount += 1
        requestedPages.append(page)
        return try await handler(page, perPage)
    }
}

final class MockTopicsInteractor: TopicsInteractorProtocol {
    var topicsHandler: (Int, Int) async throws -> [Topic] = { _, _ in [] }
    var topicPhotosHandler: (String, Int, Int) async throws -> [Photo] = { _, _, _ in [] }
    private(set) var topicsCallCount = 0
    private(set) var lastSlug: String?

    func fetchTopics(page: Int, perPage: Int) async throws -> [Topic] {
        topicsCallCount += 1
        return try await topicsHandler(page, perPage)
    }

    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [Photo] {
        lastSlug = slug
        return try await topicPhotosHandler(slug, page, perPage)
    }
}

final class MockImagesInteractor: ImagesInteractorProtocol {
    var result: Result<UIImage, Error> = .success(UIImage())
    private(set) var lastURL: URL?

    func loadImage(url: URL) async throws -> UIImage {
        lastURL = url
        return try result.get()
    }
}

final class MockSearchInteractor: SearchInteractorProtocol {
    var searchHandler: (String, Int, Int) async throws -> SearchResult = { _, _, _ in
        throw TestError()
    }
    var historyResult: Result<[String], Error> = .success([])
    var saveError: Error?
    private(set) var searchCallCount = 0
    private(set) var lastQuery: String?
    private(set) var savedKeywords: [String] = []

    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> SearchResult {
        searchCallCount += 1
        lastQuery = query
        return try await searchHandler(query, page, perPage)
    }

    func getSearchHistory() async throws -> [String] {
        try historyResult.get()
    }

    func saveSearchKeyword(_ keyword: String) async throws {
        if let saveError { throw saveError }
        savedKeywords.append(keyword)
    }
}
