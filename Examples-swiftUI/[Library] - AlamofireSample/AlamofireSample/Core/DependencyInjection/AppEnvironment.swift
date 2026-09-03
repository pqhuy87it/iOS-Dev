import Combine
import SwiftData
import UIKit

@MainActor struct AppEnvironment {
    let isRunningTests: Bool
    let diContainer: DIContainer
    let modelContainer: ModelContainer
}

extension AppEnvironment {
    static func bootstrap() -> AppEnvironment {
        let appState = Store<AppState>(AppState())
        let modelContainer = configuredModelContainer()

        let repositories = configuredRepositories(modelContainer: modelContainer)

        let interactors = configuredInteractors(appState: appState,
                                                repositories: repositories)

        let diContainer = DIContainer(appState: appState,
                                      interactors: interactors)

        return AppEnvironment(isRunningTests: ProcessInfo.processInfo.isRunningTests,
                              diContainer: diContainer,
                              modelContainer: modelContainer)
    }

    private static func configuredRepositories(modelContainer: ModelContainer) -> DIContainer.Repositories {
        let mainDBRepository = MainDBRepository(modelContainer: modelContainer)
        let apiClient = ApiClient()
        let photosRepository = PhotosRepository(apiClient: apiClient)
        let imagesRepository = ImagesRepository(apiClient: apiClient)
        let topicsRepository = TopicsRepository(apiClient: apiClient)
        let searchRepository = SearchRepository(apiClient: apiClient, dbRepository: mainDBRepository)
        return .init(images: imagesRepository,
                     photos: photosRepository,
                     topics: topicsRepository,
                     search: searchRepository)
    }

    private static func configuredModelContainer() -> ModelContainer {
        do {
            return try ModelContainer.appModelContainer()
        } catch {
            return try! ModelContainer.appModelContainer(inMemoryOnly: true)
        }
    }

    private static func configuredInteractors(appState _: Store<AppState>,
                                              repositories: DIContainer.Repositories) -> DIContainer.Interactors
    {
        let photos = PhotosInteractor(photosRepository: repositories.photos)
        let images = ImagesInteractor(repository: repositories.images)
        let topics = TopicsInteractor(topicsRepository: repositories.topics)
        let search = SearchInteractor(searchRepository: repositories.search)

        return .init(images: images,
                     photos: photos,
                     topics: topics,
                     search: search)
    }
}
