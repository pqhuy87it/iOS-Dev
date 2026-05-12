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

        // 1. Configure Web Repositories
        let webRepositories = configuredWebRepositories(session: session)
        let dbRepositories = configuredDBRepositories(modelContainer: modelContainer)

        // 2. Configure Interactors (pass webRepositories in)
        let interactors = configuredInteractors(appState: appState,
                                                webRepositories: webRepositories,
                                                dbRepositories: dbRepositories)

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

    private static func configuredWebRepositories(session: URLSession) -> DIContainer.WebRepositories {
        let unsplashRepository = UnsplashWebRepository(session: session)
        let imagesRepository = ImagesWebRepository(session: session)
        return .init(images: imagesRepository, unsplash: unsplashRepository)
    }

    private static func configuredDBRepositories(modelContainer: ModelContainer) -> DIContainer.DBRepositories {
        let mainDBRepository = MainDBRepository(modelContainer: modelContainer)
        return .init(searchDB: mainDBRepository)
    }

    private static func configuredModelContainer() -> ModelContainer {
        do {
            return try ModelContainer.appModelContainer()
        } catch {
            return try! ModelContainer.appModelContainer(inMemoryOnly: true)
        }
    }

    private static func configuredInteractors(appState _: Store<AppState>,
                                              webRepositories: DIContainer.WebRepositories,
                                              dbRepositories: DIContainer.DBRepositories) -> DIContainer.Interactors
    {
        let photos = PhotoInteractor(webRepository: webRepositories.unsplash,
                                     dbRepository: dbRepositories.searchDB)
        let images = ImagesInteractor(webRepository: webRepositories.images)

        return .init(images: images,
                     photos: photos)
    }
}

@MainActor extension AppEnvironment {
    func makeViewModelFactory() -> AppViewModelFactory {
        return AppViewModelFactory(interactors: diContainer.interactors)
    }
}
