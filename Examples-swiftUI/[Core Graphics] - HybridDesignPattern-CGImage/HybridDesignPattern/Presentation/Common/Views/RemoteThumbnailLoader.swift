import SwiftUI
import ImageIO

actor RemoteThumbnailLoader {
    static let shared = RemoteThumbnailLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 20_000_000,
                                   diskCapacity: 200_000_000)
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    func thumbnail(from url: URL, maxPixelSize: CGFloat) async throws -> UIImage {
        let key = "\(url.absoluteString)#\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let (data, _) = try await session.data(from: url)

        // Downsample thẳng từ data tải về, KHÔNG decode ảnh full-size.
        guard let thumb = Self.downsample(data, maxPixelSize: maxPixelSize) else {
            throw URLError(.cannotDecodeContentData)
        }

        cache.setObject(thumb, forKey: key)
        return thumb
    }

    nonisolated static func downsample(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        // kCGImageSourceShouldCache=false: không giữ ảnh gốc đã decode trong bộ nhớ
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }
}
