# HybridDesignPattern

A SwiftUI sample app (Unsplash photo browser) that demonstrates a **hybrid architecture**: **Clean Architecture** for layering, **MVVM** for the presentation layer, and **UDF (Unidirectional Data Flow)** for how each screen manages its state.

The app has three tabs:
- **Home** – latest photos in a Pinterest-style masonry grid with infinite scroll.
- **Topic** – curated topics, each with a horizontal carousel of photos.
- **Search** – search photos by keyword, with persisted search history and infinite scroll.

Image data comes from the [Unsplash API](https://unsplash.com/developers); search history is stored locally with **SwiftData**.

---

## Requirements

- Xcode 16+
- iOS 17+ (uses SwiftData and the modern `TabView`/`@Entry` APIs)
- A free Unsplash API access key

---

## Getting Started

### 1. Configure secrets

The Unsplash API key is **not** stored in source code. It is read at runtime from a `Secrets.plist` that is **git-ignored** (see the root `.gitignore` → `**/Secrets.plist`).

1. Get an access key: create a free app at <https://unsplash.com/oauth/applications> and copy the **Access Key**.
2. Copy the template to create your own secrets file:

   ```bash
   cp HybridDesignPattern/Config/Secrets.example.plist HybridDesignPattern/Config/Secrets.plist
   ```

3. Open `HybridDesignPattern/Config/Secrets.plist` and replace the placeholder with your real key:

   ```xml
   <dict>
       <key>UnsplashClientID</key>
       <string>YOUR_UNSPLASH_ACCESS_KEY</string>
   </dict>
   ```

4. Build & run. `Secrets.plist` is bundled as a resource and read by `AppConfig`:

   ```swift
   AppConfig.unsplashClientID   // -> value of "UnsplashClientID"
   ```

> ⚠️ Never commit `Secrets.plist`. Only `Secrets.example.plist` (the template) is tracked. If a key value is ever missing or empty, `AppConfig` triggers an `assertionFailure` in debug builds telling you to set it up.

To add a new secret later: add a `<key>`/`<string>` pair to both plists, then expose it from `AppConfig` (e.g. `static var myKey: String { string(forKey: "MyKey") }`).

---

## Architecture

This project deliberately combines three complementary ideas. They operate at different scopes and do not conflict:

| Concern | Pattern | Where |
| --- | --- | --- |
| How code is layered & which way dependencies point | **Clean Architecture** | `Domain` ← `Data`, `Presentation` |
| How a screen is structured (View ↔ logic/state) | **MVVM** | `Presentation` (View + ViewModel) |
| How a ViewModel mutates and exposes state | **UDF** | every ViewModel (`State` + `Action` + `send`) |

### 1. Clean Architecture (the layers)

The dependency rule points **inward**: `Presentation` and `Data` depend on `Domain`; `Domain` depends on nothing.

```
Presentation ─▶ Domain ◀─ Data
   (UI)         (core)    (API + DB)
```

- **Domain** – the heart of the app. Pure Swift, no framework leakage.
  - `Entities` – domain models (`Photo`, `Topic`, `User`, `SearchResult`).
  - `Interactors` – use cases (`PhotosInteractor`, `TopicsInteractor`, `SearchInteractor`, `ImagesInteractor`). They orchestrate repositories and map raw **DTOs → domain entities**.
  - `Interfaces` – the use-case protocols the Presentation layer talks to.
- **Data** – how data is actually fetched/stored.
  - `Interfaces` – repository protocols + the transport contract (`APIRepositoryProtocol`, `APICall`).
  - `Network` – `DTOs` (Codable response models, each with `toDomain()`), `APIError`, `HTTPCode`.
  - `Repositories` – concrete repositories that hit the Unsplash API (`PhotosRepository`, `TopicsRepository`, `SearchRepository`, `ImagesRepository`).
  - `Persistence` – SwiftData models (`DBModel`) and `MainDBRepository` (search history).
- **Presentation** – everything SwiftUI.
  - `Common` – reusable views/view models (`ImageView` + `ImageViewModel`, `ErrorView`).
  - `Modules` – one folder per feature (`HomePhotos`, `Topics`, `Search`), each with its `Views` and `ViewModels`.

**Mapping boundary:** Repositories return **DTOs**; Interactors call `toDomain()` and hand **domain entities** to the Presentation layer. This keeps API shapes out of the UI.

### 2. MVVM (the presentation layer)

Each screen pairs a SwiftUI `View` with a `ViewModel`:

- The **View** is declarative and "dumb": it renders `viewModel.state` and forwards user intent via `viewModel.send(...)`.
- The **ViewModel** (`@MainActor`, `ObservableObject`) holds state and depends only on **Domain interactor protocols** — never on repositories or the network directly.

ViewModels are never constructed by views directly. They are produced by a **factory** (`ViewModelFactory`) injected through the SwiftUI environment, so previews/tests can swap in a `StubViewModelFactory`.

### 3. UDF (state inside each ViewModel)

Every ViewModel follows the same Unidirectional Data Flow shape (`UDFViewModel`):

```swift
struct State { ... }          // single source of truth, immutable from the outside
enum Action { ... }           // every possible user/system intent
func send(_ action: Action)   // the ONLY entry point that mutates state
```

Flow: `View → send(Action) → ViewModel updates State → View re-renders`.

State is exposed as `@Published private(set) var state` — the View can read it but can only change it by dispatching an `Action`. Async work (network/DB) is launched inside `send`, and results are written back to `state`. Loading/loaded/failed are modeled with the `Loadable<T>` enum.

#### Example: end-to-end flow for the Home screen

```
PhotosListView                       (Presentation / View)
  └─ send(.loadPhotos) ────────────▶ PhotosViewModel            (Presentation / MVVM + UDF)
                                       └─ photosInteractor.fetchPhotos(page:perPage:)
                                            └─ PhotosInteractor   (Domain / use case)
                                                 └─ photosRepository.fetchPhotos(...) -> [PhotoDTO]
                                                      └─ PhotosRepository  (Data / Unsplash API)
                                                 └─ dtos.map { $0.toDomain() } -> [Photo]
                                       └─ state.photos = .loaded([Photo])
  ◀── re-render masonry grid ────────┘
```

---

## Project Structure

```
HybridDesignPattern/
├── App/                         # @main entry point + root TabView
│   ├── HybridDesignPatternApp.swift
│   └── HybridDesignPatternMainView.swift
├── Config/
│   ├── AppConfig.swift          # reads secrets from Secrets.plist
│   ├── Secrets.example.plist    # template (committed)
│   └── Secrets.plist            # real keys (git-ignored, you create this)
├── Core/                        # cross-cutting infrastructure
│   ├── AppState/                # global app state (Store<AppState>)
│   ├── DependencyInjection/     # DIContainer + AppEnvironment (composition root)
│   ├── Extensions/              # Loadable, Store, CancelBag, helpers, mocks
│   ├── Factories/               # ViewModelFactory (+ App/Stub implementations)
│   └── UDF/                     # UDFViewModel protocol
├── Domain/                      # ── inner layer, no framework dependencies ──
│   ├── Entities/                # Photo, Topic, User, SearchResult
│   ├── Interactors/             # use cases (map DTO -> entity)
│   └── Interfaces/              # use-case protocols
├── Data/                        # ── outer layer: how data is fetched/stored ──
│   ├── Interfaces/              # repository + transport protocols (APICall, APIRepositoryProtocol)
│   ├── Network/                 # DTOs, APIError, HTTPCode
│   ├── Repositories/            # concrete API repositories
│   └── Persistence/             # SwiftData models + MainDBRepository
└── Presentation/                # ── SwiftUI layer ──
    ├── Common/                  # ImageView/ImageViewModel, ErrorView
    └── Modules/
        ├── HomePhotos/          # Views + ViewModels
        ├── Topics/
        └── Search/
```

### Composition root

`AppEnvironment.bootstrap()` is where everything is wired together: it builds the `URLSession`, the SwiftData `ModelContainer`, all repositories, all interactors, and packs them into a `DIContainer`. The `DIContainer` and a `ViewModelFactory` are injected into the SwiftUI environment, so each screen pulls a fully-configured ViewModel from the factory.

---

## Notable features

- **Masonry grid** – `PhotosListView` and `SearchView` lay photos into the shortest column based on each photo's aspect ratio.
- **Infinite scroll** – when the last cell appears, the ViewModel loads the next page and appends it; a guard on `isLoadingMore`/`canLoadMore` prevents duplicate requests.
- **Async image loading** – `ImageView` reserves an aspect-ratio placeholder and loads the real image via its own `ImageViewModel`.
- **Search history** – persisted with SwiftData via `MainDBRepository`, surfaced through `SearchRepository`.
