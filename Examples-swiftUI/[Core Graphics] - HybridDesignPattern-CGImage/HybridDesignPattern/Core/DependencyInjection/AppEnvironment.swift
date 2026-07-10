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
        let session = configuredURLSession()
        let modelContainer = configuredModelContainer()

        // 1. Configure Repositories (gộp cả API lẫn DB)
        let repositories = configuredRepositories(session: session,
                                                  modelContainer: modelContainer)

        // 2. Configure Interactors
        let interactors = configuredInteractors(appState: appState,
                                                repositories: repositories)

        let diContainer = DIContainer(appState: appState,
                                      interactors: interactors)

        return AppEnvironment(isRunningTests: ProcessInfo.processInfo.isRunningTests,
                              diContainer: diContainer,
                              modelContainer: modelContainer)
    }

    private static func configuredURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 5
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = .shared
        return URLSession(configuration: configuration)
    }

    private static func configuredRepositories(session: URLSession,
                                               modelContainer: ModelContainer) -> DIContainer.Repositories {
        let mainDBRepository = MainDBRepository(modelContainer: modelContainer)
        let photosRepository = PhotosRepository(session: session)
        let imagesRepository = ImagesRepository(session: session)
        let topicsRepository = TopicsRepository(session: session)
        let searchRepository = SearchRepository(session: session, dbRepository: mainDBRepository)
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

@MainActor extension AppEnvironment {
    func makeViewModelFactory() -> AppViewModelFactory {
        return AppViewModelFactory(interactors: diContainer.interactors,
                                   appState: diContainer.appState)
    }
}
