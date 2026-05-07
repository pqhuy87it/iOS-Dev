import Foundation

struct PhotoInteractor: PhotoInteractorProtocol {
    // 2. Depend on Protocol (UnsplashWebRepository) instead of UnsplashWebRepository
    let webRepository: UnsplashWebRepositoryProtocol
    let dbRepository: SearchDBRepositoryProtocol
    
    // Assign default values for page and perPage for brevity when calling
    func fetchPhotos(page: Int = 1, perPage: Int = 10) async throws -> [Photo] {
        // 3. Add 'try await' and page should start from 1
        let photoDTOs = try await webRepository.fetchLatestPhotos(page: page, perPage: perPage)
        let photos = self.transformFetchedPhotos(photos: photoDTOs)
        return photos
    }
    
    func searchPhotos(query: String, page: Int = 1, perPage: Int = 10) async throws -> SearchResult {
        let resultDTOs = try await webRepository.searchPhotos(query: query, page: page, perPage: perPage)
        let results = self.transformSearchResult(searchResultDTO: resultDTOs)
        return results
    }
    
    func fetchTopics(page: Int = 1, perPage: Int = 10) async throws -> [Topic] {
        let topicDTOs = try await webRepository.fetchTopics(page: page, perPage: perPage)
        return self.transformFetchedTopics(topics: topicDTOs)
    }
    
    func fetchTopicPhotos(slug: String, page: Int = 1, perPage: Int = 30) async throws -> [Photo] {
        let topicPhotoDTOs = try await webRepository.fetchTopicPhotos(slug: slug, page: page, perPage: perPage)
        return self.transformFetchedPhotos(photos: topicPhotoDTOs)
    }
    
    func getSearchHistory() async throws -> [String] {
        let history = try await dbRepository.fetchSearchHistory()
        return history.map { $0.keyword }
    }
    
    func saveSearchKeyword(_ keyword: String) async throws {
        try await dbRepository.saveSearchKeyword(keyword)
    }
    
    private func transformFetchedPhotos(photos: [ApiModel.Photo]) -> [Photo] {
        photos.map { Photo(id: $0.id,
                           width: $0.width,
                           height: $0.height,
                           color: $0.color,
                           description: $0.description,
                           altDescription: $0.altDescription,
                           urls: Photo.Urls(raw: $0.urls.raw,
                                            full: $0.urls.full,
                                            regular: $0.urls.regular,
                                            small: $0.urls.small,
                                            thumb: $0.urls.thumb),
                           user: User(id: $0.user.id,
                                      username: $0.user.username,
                                      name: $0.user.name)) }
    }
    
    private func transformSearchResult(searchResultDTO: ApiModel.SearchResult) -> SearchResult {
        SearchResult(total: searchResultDTO.total,
                     totalPages: searchResultDTO.totalPages,
                     results: transformFetchedPhotos(photos: searchResultDTO.results))
    }
    
    private func transformFetchedTopics(topics: [ApiModel.Topic]) -> [Topic] {
        topics.map { Topic(id: $0.id,
                           slug: $0.slug,
                           title: $0.title,
                           description: $0.description,
                           coverPhoto: $0.coverPhoto.map { cover in
            Photo(id: cover.id,
                  width: cover.width,
                  height: cover.height,
                  color: cover.color,
                  description: cover.description,
                  altDescription: cover.altDescription,
                  urls: Photo.Urls(raw: cover.urls.raw,
                                   full: cover.urls.full,
                                   regular: cover.urls.regular,
                                   small: cover.urls.small,
                                   thumb: cover.urls.thumb),
                  user: User(id: cover.user.id,
                             username: cover.user.username,
                             name: cover.user.name))
        }) }
    }
}