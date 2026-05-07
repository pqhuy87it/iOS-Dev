import ComposableArchitecture
import Foundation

// 1. Định nghĩa Client với đầy đủ 4 hàm
@DependencyClient
struct UnsplashClient {
    var fetchPhotos: (_ page: Int, _ perPage: Int) async throws -> [Photo]
    var searchPhotos: (_ query: String, _ page: Int, _ perPage: Int) async throws -> SearchResult
    var fetchTopics: (_ page: Int, _ perPage: Int) async throws -> [Topic]
    var fetchTopicPhotos: (_ slug: String, _ page: Int, _ perPage: Int) async throws -> [Photo]
}

// 2. Cài đặt chi tiết (Logic Map dữ liệu từ Interactor cũ sẽ nằm ở đây)
extension UnsplashClient: DependencyKey {
    
    static let liveValue: UnsplashClient = {
        // Khởi tạo Repository gốc của bạn
        let repository = UnsplashWebRepository(session: .shared)
        
        // --- CÁC HÀM HELPER ĐỂ MAP DỮ LIỆU ---
        // (Thay thế cho các hàm transform... trong PhotoInteractor cũ của bạn)
        let mapUser: (ApiModel.User) -> User = { dto in
            User(id: dto.id, username: dto.username, name: dto.name)
        }
        
        let mapPhoto: (ApiModel.Photo) -> Photo = { dto in
            Photo(
                id: dto.id, width: dto.width, height: dto.height, color: dto.color,
                description: dto.description, altDescription: dto.altDescription,
                urls: Photo.Urls(
                    raw: dto.urls.raw, full: dto.urls.full,
                    regular: dto.urls.regular, small: dto.urls.small, thumb: dto.urls.thumb
                ),
                user: mapUser(dto.user)
            )
        }
        // ------------------------------------
        
        return Self(
            // 1. Fetch Latest Photos
            fetchPhotos: { page, perPage in
                let dtos = try await repository.fetchLatestPhotos(page: page, perPage: perPage)
                return dtos.map(mapPhoto)
            },
            
            // 2. Search Photos
            searchPhotos: { query, page, perPage in
                let dto = try await repository.searchPhotos(query: query, page: page, perPage: perPage)
                return SearchResult(
                    total: dto.total,
                    totalPages: dto.totalPages,
                    results: dto.results.map(mapPhoto)
                )
            },
            
            // 3. Fetch Topics
            fetchTopics: { page, perPage in
                let dtos = try await repository.fetchTopics(page: page, perPage: perPage)
                return dtos.map { topicDto in
                    Topic(
                        id: topicDto.id,
                        slug: topicDto.slug,
                        title: topicDto.title,
                        description: topicDto.description,
                        coverPhoto: topicDto.coverPhoto.map(mapPhoto) // Map coverPhoto nếu có
                    )
                }
            },
            
            // 4. Fetch Topic Photos
            fetchTopicPhotos: { slug, page, perPage in
                let dtos = try await repository.fetchTopicPhotos(slug: slug, page: page, perPage: perPage)
                return dtos.map(mapPhoto)
            }
        )
    }()
    
    // Mock data cực kỳ tiện lợi cho SwiftUI Previews
    static let previewValue = Self(
        fetchPhotos: { _, _ in [.mock] },
        searchPhotos: { _, _, _ in SearchResult(total: 100, totalPages: 10, results: [.mock]) },
        fetchTopics: { _, _ in [.mock] },
        fetchTopicPhotos: { _, _, _ in [.mock] }
    )
}

// 3. Đăng ký vào hệ thống Dependency của TCA
extension DependencyValues {
    var unsplashClient: UnsplashClient {
        get { self[UnsplashClient.self] }
        set { self[UnsplashClient.self] = newValue }
    }
}
