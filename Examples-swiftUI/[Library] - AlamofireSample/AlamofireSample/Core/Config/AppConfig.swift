import Foundation

enum AppConfig {

    /// Unsplash API access key (Client-ID).
    static var unsplashClientID: String { string(forKey: "UnsplashClientID") }

    // MARK: - Plist loader

    private static let secrets: [String: Any] = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url) as? [String: Any]
        else {
            assertionFailure("""
            ⚠️ Secrets.plist not found in the bundle. Please copy Config/Secrets.example.plist -> Config/Secrets.plist and fill in the actual values..
            """)
            
            return [:]
        }
        
        return dict
    }()

    private static func string(forKey key: String) -> String {
        guard let value = secrets[key] as? String, !value.isEmpty else {
            assertionFailure("⚠️ Missing or empty key '\(key)' in Secrets.plist.")
            return ""
        }
        
        return value
    }
}
