import Foundation

#if DEBUG
extension Photo {
    static let mock = Photo(
        id: "1",
        width: 1080,
        height: 1920,
        color: "#000000",
        description: "A beautiful spring landscape",
        altDescription: "Spring flowers",
        urls: Photo.Urls(
            raw: URL(string: "https://images.unsplash.com/photo-1490750967868-88aa4486c946")!,
            full: URL(string: "https://images.unsplash.com/photo-1490750967868-88aa4486c946")!,
            regular: URL(string: "https://images.unsplash.com/photo-1490750967868-88aa4486c946")!,
            small: URL(string: "https://images.unsplash.com/photo-1490750967868-88aa4486c946")!,
            thumb: URL(string: "https://images.unsplash.com/photo-1490750967868-88aa4486c946")!
        ),
        user: User(id: "1",
                   username: "test",
                   name: "john",
                   firstName: "ivo",
                   lastName: "moka",
                   instagramUsername: "",
                   twitterUsername: "",
                   portfolioUrl: nil,
                   totalCollections: 0,
                   profileImage: User.ProfileImage(small: URL(string: "https://google.com")!,
                                                   medium: URL(string: "https://google.com")!,
                                                   large: URL(string: "https://google.com")!))
    )
}

extension Topic {
    static let mock = Topic(
        id: "t1",
        slug: "spring",
        title: "Spring Escapes",
        description: "Beautiful destinations to visit this spring.",
        coverPhoto: Photo.mock
    )
}
#endif
