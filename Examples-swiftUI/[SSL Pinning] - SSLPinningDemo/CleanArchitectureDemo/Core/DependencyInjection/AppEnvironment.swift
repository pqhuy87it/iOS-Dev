import UIKit
import SwiftData
import Combine

@MainActor
struct AppEnvironment {
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
            
            let diContainer = DIContainer(appState: appState, interactors: interactors)
            
            return AppEnvironment(
                isRunningTests: ProcessInfo.processInfo.isRunningTests,
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

        // Pinning is disabled in DEBUG so Charles/mitmproxy can intercept traffic.
//        #if DEBUG
//        return URLSession(configuration: configuration)
//        #else
        let delegate = SSLPinningDelegate(pinnedDomains: pinnedDomains())
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
//        #endif
    }

    /// Domains and their pinning policies for RELEASE builds.
    ///
    /// How to get the public-key hash for a host:
    ///   openssl s_client -connect api.unsplash.com:443 2>/dev/null \
    ///     | openssl x509 -pubkey -noout \
    ///     | openssl pkey -pubin -outform DER \
    ///     | openssl dgst -sha256 -binary \
    ///     | base64
    ///
    /// Add a backup hash (next certificate) alongside the current one so you
    /// can rotate without a forced update.
    private static func pinnedDomains() -> [String: SSLPinningDelegate.PinningMode] {
        [
            "api.unsplash.com": .publicKey(hashes: [
                // Replace with the real SHA-256 SPKI hash(es) from the command above.
                "AYPYJLVU3pG/1G/91agkdpRH0s69R0pgl0eude3Na18="
            ]),
            "images.unsplash.com": .publicKey(hashes: [
                // Replace with the real SHA-256 SPKI hash(es) from the command above.
                "XBbn+hw/7cMf+xEqW+p5CYf2cpvWidpbIjhJauBVx20="
            ])
        ]
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

    private static func configuredInteractors(
            appState: Store<AppState>,
            webRepositories: DIContainer.WebRepositories,
            dbRepositories: DIContainer.DBRepositories
        ) -> DIContainer.Interactors {
            let photos = PhotoInteractor(webRepository: webRepositories.unsplash,
                                         dbRepository: dbRepositories.searchDB)
            let images = ImagesInteractor(webRepository: webRepositories.images)
                
            return .init(images: images, photos: photos)
        }
}
