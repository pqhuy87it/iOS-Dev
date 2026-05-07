import Foundation

#if DEBUG
extension ApiModel.Photo {
    static let mock = ApiModel.Photo(
        id: "1",
        width: 1080,
        height: 1920,
        color: "#000000",
        description: "A beautiful spring landscape",
        altDescription: "Spring flowers",
        urls: ApiModel.PhotoUrls(
            raw: URL(string: "https://images.unsplash.com/photo-1490750967868-88aa4486c946")!,
            full: URL(string: "https://images.unsplash.com/photo-1490750967868-88aa4486c946")!,
            regular: URL(string: "https://images.unsplash.com/photo-1490750967868-88aa4486c946")!,
            small: URL(string: "https://images.unsplash.com/photo-1490750967868-88aa4486c946")!,
            thumb: URL(string: "https://images.unsplash.com/photo-1490750967868-88aa4486c946")!
        ),
        user: ApiModel.User(id: "u1", username: "nature_lover", name: "John Nature")
    )
}

extension ApiModel.Topic {
    static let mock = ApiModel.Topic(
        id: "t1",
        slug: "spring",
        title: "Spring Escapes",
        description: "Beautiful destinations to visit this spring.",
        coverPhoto: ApiModel.Photo.mock
    )
}
#endif
