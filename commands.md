# SwiftUI: `.commands` — Giải thích chi tiết

## 1. Bản chất — Menu bar commands cho macOS (và iPad keyboard shortcuts)

`.commands` là modifier trên `Scene` cho phép **thêm, sửa, thay thế menu items** trong **menu bar** (macOS) và **keyboard shortcuts** (macOS + iPad với external keyboard). Nó tương đương việc customise menu bar trong AppKit nhưng bằng SwiftUI declarative.

```
macOS Menu Bar:
┌──────────────────────────────────────────────────────┐
│ FocusCookbook  File  Edit  View  Recipes  Help       │
│                                   ↑                  │
│                              Custom menu              │
│                              từ .commands             │
└──────────────────────────────────────────────────────┘

iPad (external keyboard):
  Giữ phím ⌘ → hiện overlay keyboard shortcuts
  Shortcuts đến từ .commands
```

---

## 2. Phân tích đoạn code

```swift
@main
struct FocusCookbookApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 800, height: 600)
        // ↑ macOS only: window mặc định 800×600
        #endif
        .commands {
            SidebarCommands()
            // ↑ Built-in: thêm menu "View > Toggle Sidebar"
            //   Cho phép user ẩn/hiện sidebar bằng menu hoặc ⌘⇧S
            
            RecipeCommands()
            // ↑ Custom: commands struct tự định nghĩa
            //   Thêm menu items tuỳ ý (ví dụ "Recipes" menu)
        }
    }
}
```

### `.commands` là modifier trên Scene, KHÔNG phải View

```swift
WindowGroup {
    ContentView()
}
.commands { ... }    // ✅ Modifier trên WindowGroup (Scene)

// ❌ KHÔNG phải:
ContentView()
    .commands { ... }  // ❌ Không tồn tại trên View
```

### `SidebarCommands()` — Built-in command group

Apple cung cấp sẵn một số command groups:

```swift
.commands {
    SidebarCommands()
    // Thêm vào menu "View":
    //   View > Toggle Sidebar    (⌘⇧S hoặc ⌃⌘S)
    // Tự động hoạt động với NavigationSplitView
}
```

```
Menu "View" sau khi thêm SidebarCommands:
┌─────────────────────┐
│ View                │
├─────────────────────┤
│ Toggle Sidebar  ⌃⌘S │  ← SidebarCommands thêm
│ Enter Full Screen    │
└─────────────────────┘
```

### `RecipeCommands()` — Custom command group (tự viết)

```swift
struct RecipeCommands: Commands {
    // ↑ Conform protocol Commands
    
    var body: some Commands {
        // ↑ Giống View có var body: some View
        
        CommandMenu("Recipes") {
            // ↑ Tạo menu MỚI tên "Recipes" trên menu bar
            
            Button("Add Recipe") {
                // Action khi click hoặc ⌘N
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Button("Import Recipes...") {
                // Action
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Delete Recipe") {
                // Action
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }
    }
}
```

```
Menu bar kết quả:
┌───────────────────────────────────────────────────────┐
│ FocusCookbook  File  Edit  View  Recipes  Help        │
└───────────────────────────────────┬───────────────────┘
                                    │
                              ┌─────┴──────────────────┐
                              │ Add Recipe         ⌘N   │
                              │ Import Recipes...  ⇧⌘I  │
                              ├────────────────────────┤
                              │ Delete Recipe      ⌘⌫   │
                              └────────────────────────┘
```

---

## 3. `Commands` Protocol

```swift
protocol Commands {
    associatedtype Body: Commands
    @CommandsBuilder
    var body: Self.Body { get }
}
```

Giống `View` protocol — có `body`, dùng `@CommandsBuilder` (result builder) để khai báo declarative.

---

## 4. Ba cách tạo Commands

### 4.1 `CommandMenu` — Tạo menu MỚI trên menu bar

```swift
struct MyCommands: Commands {
    var body: some Commands {
        CommandMenu("Tools") {
            // Tạo menu "Tools" hoàn toàn mới
            Button("Run Script") { runScript() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            
            Button("Format Code") { formatCode() }
                .keyboardShortcut("f", modifiers: [.command, .option])
            
            Divider()
            
            Menu("Export As") {
                // Submenu
                Button("PDF") { exportPDF() }
                Button("HTML") { exportHTML() }
                Button("Markdown") { exportMarkdown() }
            }
        }
    }
}
```

```
┌──────────────────────────────────────────────┐
│ App  File  Edit  View  Tools  Help           │
└──────────────────────────┬───────────────────┘
                           │
                     ┌─────┴──────────────────┐
                     │ Run Script       ⇧⌘R    │
                     │ Format Code      ⌥⌘F    │
                     ├────────────────────────┤
                     │ Export As          ▶    │
                     │  ┌─────────────────┐   │
                     │  │ PDF             │   │
                     │  │ HTML            │   │
                     │  │ Markdown        │   │
                     │  └─────────────────┘   │
                     └────────────────────────┘
```

### 4.2 `CommandGroup` — Thêm/Sửa vào menu CÓ SẴN

Thêm items vào menu system đã tồn tại (File, Edit, View, Help...):

```swift
struct FileCommands: Commands {
    var body: some Commands {
        // Thêm VÀO SAU mục "New" trong menu File
        CommandGroup(after: .newItem) {
            Button("New Recipe") { createRecipe() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            
            Button("New Collection") { createCollection() }
        }
        
        // Thêm VÀO TRƯỚC mục "Save" trong menu File
        CommandGroup(before: .saveItem) {
            Button("Quick Save") { quickSave() }
                .keyboardShortcut("s", modifiers: [.command, .option])
        }
        
        // THAY THẾ hoàn toàn mục Help
        CommandGroup(replacing: .help) {
            Button("Recipe Guide") { openGuide() }
            Button("Contact Support") { openSupport() }
            Divider()
            Button("About FocusCookbook") { showAbout() }
        }
    }
}
```

### Placement options cho CommandGroup

```swift
// Thêm SAU một group
CommandGroup(after: .newItem) { }        // sau File > New
CommandGroup(after: .saveItem) { }       // sau File > Save
CommandGroup(after: .importExport) { }   // sau File > Import/Export
CommandGroup(after: .printItem) { }      // sau File > Print
CommandGroup(after: .undoRedo) { }       // sau Edit > Undo/Redo
CommandGroup(after: .pasteboard) { }     // sau Edit > Cut/Copy/Paste
CommandGroup(after: .textEditing) { }    // sau Edit > Find/Replace
CommandGroup(after: .sidebar) { }        // sau View > Sidebar
CommandGroup(after: .toolbar) { }        // sau View > Toolbar
CommandGroup(after: .windowSize) { }     // sau Window > Size
CommandGroup(after: .help) { }           // sau Help
CommandGroup(after: .appInfo) { }        // sau App > About
CommandGroup(after: .appSettings) { }    // sau App > Settings
CommandGroup(after: .appVisibility) { }  // sau App > Hide

// Thêm TRƯỚC
CommandGroup(before: .newItem) { }
CommandGroup(before: .saveItem) { }
// ... tương tự

// THAY THẾ hoàn toàn
CommandGroup(replacing: .newItem) { }
CommandGroup(replacing: .help) { }
// ... tương tự
```

### 4.3 Kết hợp nhiều command groups

```swift
struct AppCommands: Commands {
    var body: some Commands {
        // Menu mới
        CommandMenu("Recipes") {
            Button("Add Recipe") { }
        }
        
        // Sửa menu File
        CommandGroup(after: .newItem) {
            Button("New from Template...") { }
        }
        
        // Sửa menu Help
        CommandGroup(replacing: .help) {
            Button("Cookbook Guide") { }
        }
    }
}
```

---

## 5. Commands với `@FocusedValue` / `@FocusedBinding` — Tương tác với active view

### Vấn đề: Commands ở Scene level, data ở View level

```
Scene (.commands)
  └── WindowGroup
        └── NavigationSplitView
              ├── Sidebar
              └── DetailView ← data nằm ở đây
                    └── RecipeEditor ← recipe đang edit
                    
Commands cần biết: recipe nào đang active?
Để enable/disable menu items, thực hiện action đúng recipe
```

### Giải pháp: FocusedValue bridge

**Bước 1: Định nghĩa FocusedValueKey**

```swift
struct FocusedRecipeKey: FocusedValueKey {
    typealias Value = Binding<Recipe>
}

extension FocusedValues {
    var recipe: Binding<Recipe>? {
        get { self[FocusedRecipeKey.self] }
        set { self[FocusedRecipeKey.self] = newValue }
    }
}
```

**Bước 2: View publish focused value**

```swift
struct RecipeEditor: View {
    @Binding var recipe: Recipe
    
    var body: some View {
        Form {
            TextField("Name", text: $recipe.name)
            // ...
        }
        .focusedSceneValue(\.recipe, $recipe)
        // ↑ "Recipe đang edit ở view này" → publish lên Scene
        // Chỉ active khi view này đang focused
    }
}
```

**Bước 3: Commands đọc focused value**

```swift
struct RecipeCommands: Commands {
    @FocusedBinding(\.recipe) var recipe
    // ↑ Nhận recipe từ view đang focused
    //   nil nếu không view nào publish recipe
    
    var body: some Commands {
        CommandMenu("Recipes") {
            Button("Favorite") {
                recipe?.isFavorite.toggle()
                // ↑ Modify recipe đang active
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(recipe == nil)
            // ↑ Disable khi không có recipe active
            
            Button("Delete Recipe") {
                // delete action
            }
            .disabled(recipe == nil)
        }
    }
}
```

```
Khi RecipeEditor focused:
┌─── Recipes ─────────────┐
│ ⭐ Favorite        ⇧⌘F  │  ← enabled
│ 🗑 Delete Recipe         │  ← enabled
└─────────────────────────┘

Khi không có RecipeEditor:
┌─── Recipes ─────────────┐
│ ⭐ Favorite        ⇧⌘F  │  ← disabled (grayed out)
│ 🗑 Delete Recipe         │  ← disabled
└─────────────────────────┘
```

### @FocusedValue vs @FocusedBinding

```swift
// @FocusedValue — đọc read-only
@FocusedValue(\.recipe) var recipe: Recipe?
// recipe là Optional<Recipe>, không phải Binding

// @FocusedBinding — đọc/ghi (Binding)
@FocusedBinding(\.recipe) var recipe: Recipe?
// recipe là Optional<Recipe>, nhưng có thể ghi ngược lại
// $recipe là Optional<Binding<Recipe>>
```

---

## 6. `keyboardShortcut` — Phím tắt

### Cú pháp

```swift
Button("Action") { }
    .keyboardShortcut("n", modifiers: .command)           // ⌘N
    .keyboardShortcut("n", modifiers: [.command, .shift])  // ⇧⌘N
    .keyboardShortcut("n", modifiers: [.command, .option]) // ⌥⌘N
    .keyboardShortcut(.delete, modifiers: .command)        // ⌘⌫
    .keyboardShortcut(.return, modifiers: .command)         // ⌘↩
    .keyboardShortcut(.escape)                              // ⎋
    .keyboardShortcut(.tab, modifiers: .command)            // ⌘⇥
    .keyboardShortcut(.upArrow, modifiers: .command)        // ⌘↑
```

### Modifier keys

```swift
.command     // ⌘
.shift       // ⇧
.option      // ⌥ (Alt)
.control     // ⌃

// Kết hợp:
[.command, .shift]           // ⇧⌘
[.command, .option]          // ⌥⌘
[.command, .shift, .option]  // ⌥⇧⌘
```

### Special keys

```swift
.return          // ↩ (Enter)
.delete          // ⌫ (Backspace)
.deleteForward   // ⌦
.escape          // ⎋
.tab             // ⇥
.space           // Space
.upArrow         // ↑
.downArrow       // ↓
.leftArrow       // ←
.rightArrow      // →
.home            // Home
.end             // End
.pageUp          // Page Up
.pageDown        // Page Down
```

### Keyboard shortcuts NGOÀI commands — trong View

```swift
// Shortcuts cũng hoạt động trong View bình thường (không chỉ commands)
struct ContentView: View {
    var body: some View {
        VStack {
            // ...
        }
        .keyboardShortcut("r", modifiers: .command)  // ← trên View

        Button("Refresh") { refresh() }
            .keyboardShortcut("r", modifiers: .command)
        // ← ⌘R trigger nút này từ bất kỳ đâu trong window
    }
}
```

---

## 7. Built-in Command Groups

Apple cung cấp sẵn một số `Commands` struct:

```swift
.commands {
    SidebarCommands()
    // → View > Toggle Sidebar

    TextEditingCommands()
    // → Edit > Find, Replace, etc.

    TextFormattingCommands()
    // → Format > Bold, Italic, Underline, etc.

    ToolbarCommands()
    // → View > Toggle Toolbar, Customize Toolbar

    EmptyCommands()
    // → Xoá tất cả default commands (dùng khi muốn menu bar trống)
}
```

### Xoá menu mặc định

```swift
.commands {
    // Xoá menu "New Window" mặc định
    CommandGroup(replacing: .newItem) { }
    // ← Empty closure = xoá hết items trong group đó
    
    // Xoá Help menu
    CommandGroup(replacing: .help) { }
}
```

---

## 8. Ví dụ thực tế hoàn chỉnh — Recipe App

### App entry point

```swift
@main
struct RecipeApp: App {
    @State private var store = RecipeStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        #if os(macOS)
        .defaultSize(width: 900, height: 600)
        #endif
        .commands {
            SidebarCommands()
            RecipeCommands()
            FileExportCommands()
            ViewCommands()
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        // ↑ macOS: App > Settings... (⌘,) mở SettingsView
        #endif
    }
}
```

### Custom commands

```swift
struct RecipeCommands: Commands {
    @FocusedBinding(\.selectedRecipe) var recipe
    @FocusedValue(\.recipeNavigation) var navigation
    
    var body: some Commands {
        CommandMenu("Recipes") {
            // Section 1: CRUD
            Button("New Recipe") {
                navigation?.createNew()
            }
            .keyboardShortcut("n", modifiers: [.command])
            
            Button("Duplicate Recipe") {
                navigation?.duplicate()
            }
            .keyboardShortcut("d", modifiers: [.command])
            .disabled(recipe == nil)
            
            Divider()
            
            // Section 2: Properties
            Button("Toggle Favorite") {
                recipe?.isFavorite.toggle()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(recipe == nil)
            
            Menu("Set Category") {
                ForEach(RecipeCategory.allCases) { category in
                    Button(category.rawValue) {
                        recipe?.category = category
                    }
                }
            }
            .disabled(recipe == nil)
            
            Divider()
            
            // Section 3: Dangerous
            Button("Delete Recipe") {
                navigation?.deleteSelected()
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(recipe == nil)
        }
    }
}

struct FileExportCommands: Commands {
    @FocusedValue(\.selectedRecipe) var recipe
    
    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Export as PDF...") {
                exportPDF(recipe)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(recipe == nil)
            
            Button("Share Recipe...") {
                shareRecipe(recipe)
            }
        }
    }
}

struct ViewCommands: Commands {
    @AppStorage("showIngredients") var showIngredients = true
    @AppStorage("showNutrition") var showNutrition = false
    
    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Toggle("Show Ingredients Panel", isOn: $showIngredients)
                .keyboardShortcut("1", modifiers: [.command, .option])
            
            Toggle("Show Nutrition Info", isOn: $showNutrition)
                .keyboardShortcut("2", modifiers: [.command, .option])
        }
    }
}
```

### FocusedValues setup

```swift
// Keys
struct SelectedRecipeKey: FocusedValueKey {
    typealias Value = Binding<Recipe>
}

struct RecipeNavigationKey: FocusedValueKey {
    typealias Value = RecipeNavigation
}

extension FocusedValues {
    var selectedRecipe: Binding<Recipe>? {
        get { self[SelectedRecipeKey.self] }
        set { self[SelectedRecipeKey.self] = newValue }
    }
    var recipeNavigation: RecipeNavigation? {
        get { self[RecipeNavigationKey.self] }
        set { self[RecipeNavigationKey.self] = newValue }
    }
}

// Navigation actions
class RecipeNavigation: ObservableObject {
    func createNew() { /* ... */ }
    func duplicate() { /* ... */ }
    func deleteSelected() { /* ... */ }
}

// View publish values
struct RecipeDetailView: View {
    @Binding var recipe: Recipe
    @StateObject var navigation = RecipeNavigation()
    
    var body: some View {
        RecipeEditor(recipe: $recipe)
            .focusedSceneValue(\.selectedRecipe, $recipe)
            .focusedSceneValue(\.recipeNavigation, navigation)
    }
}
```

### Menu bar kết quả

```
┌────────────────────────────────────────────────────────────┐
│ RecipeApp  File  Edit  View  Recipes  Help                 │
└──────────────────┬──────┬─────────────┬────────────────────┘
                   │      │             │
              ┌────┴───┐  │        ┌────┴──────────────┐
              │ ...    │  │        │ New Recipe     ⌘N  │
              │ Export │  │        │ Duplicate      ⌘D  │
              │  as PDF│  │        ├────────────────────┤
              │ Share  │  │        │ Toggle Fav    ⇧⌘F  │
              └────────┘  │        │ Set Category   ▶   │
                          │        ├────────────────────┤
                     ┌────┴──────┐ │ Delete Recipe  ⌘⌫  │
                     │ Toggle    │ └────────────────────┘
                     │  Sidebar  │
                     │ Show      │
                     │  Ingred.  │
                     │ Show      │
                     │  Nutrition│
                     └───────────┘
```

---

## 9. Commands trên iPad

### iPad với external keyboard

```swift
// Commands TỰ ĐỘNG thành keyboard shortcuts trên iPad
// User giữ ⌘ → hiện discoverability overlay

Button("Add Recipe") { }
    .keyboardShortcut("n", modifiers: .command)
// iPad: giữ ⌘ → hiện "⌘N Add Recipe" trong overlay
// macOS: hiện trong menu bar
```

```
iPad keyboard shortcuts overlay (giữ ⌘):
┌──────────────────────────────────┐
│ Recipes                          │
│   ⌘N    Add Recipe               │
│   ⇧⌘F   Toggle Favorite          │
│   ⌘⌫    Delete Recipe            │
│                                  │
│ File                             │
│   ⇧⌘E   Export as PDF            │
└──────────────────────────────────┘
```

### iPhone — Commands không hiển thị

```swift
// iPhone không có menu bar hoặc keyboard shortcut overlay
// .commands vẫn compile nhưng KHÔNG hiển thị
// Phải cung cấp UI alternative (buttons, swipe actions, context menu)
```

---

## 10. Sai lầm thường gặp

### ❌ Đặt .commands trên View thay vì Scene

```swift
// ❌ .commands không tồn tại trên View
struct ContentView: View {
    var body: some View {
        Text("Hello")
            .commands { }    // ❌ Compile error
    }
}

// ✅ Đặt trên Scene (WindowGroup, DocumentGroup...)
WindowGroup {
    ContentView()
}
.commands {
    MyCommands()
}
```

### ❌ Quên disable menu item khi không có context

```swift
// ❌ Button luôn enabled dù không có recipe
CommandMenu("Recipes") {
    Button("Delete Recipe") {
        recipe?.delete()    // crash hoặc no-op nếu recipe = nil
    }
}

// ✅ Disable khi không có recipe
Button("Delete Recipe") { recipe?.delete() }
    .disabled(recipe == nil)
```

### ❌ Keyboard shortcut trùng system

```swift
// ❌ ⌘C đã là Copy — ghi đè gây confuse
Button("Custom Action") { }
    .keyboardShortcut("c", modifiers: .command)    // ❌ trùng Copy

// ✅ Dùng modifier bổ sung hoặc key khác
Button("Custom Action") { }
    .keyboardShortcut("c", modifiers: [.command, .shift])    // ⇧⌘C
```

### ❌ Quên #if os(macOS) cho macOS-only features

```swift
// ❌ defaultSize không tồn tại trên iOS → compile error nếu target iOS
WindowGroup { ContentView() }
    .defaultSize(width: 800, height: 600)

// ✅ Conditional compilation
WindowGroup { ContentView() }
    #if os(macOS)
    .defaultSize(width: 800, height: 600)
    #endif
```

---

## 11. Tóm tắt

| Concept | Vai trò |
|---|---|
| **`.commands { }`** | Scene modifier — thêm/sửa menu bar commands |
| **`Commands` protocol** | Struct khai báo menu items (giống View protocol) |
| **`CommandMenu("Name")`** | Tạo menu **MỚI** trên menu bar |
| **`CommandGroup(after/before/replacing:)`** | Thêm/sửa vào menu **CÓ SẴN** |
| **`SidebarCommands()`** | Built-in: Toggle Sidebar |
| **`TextEditingCommands()`** | Built-in: Find/Replace |
| **`.keyboardShortcut()`** | Gán phím tắt cho Button/Toggle |
| **`@FocusedValue`** | Đọc data từ view đang focused — bridge View ↔ Commands |
| **`@FocusedBinding`** | Đọc/ghi Binding từ view đang focused |
| **`.focusedSceneValue()`** | View publish data lên Scene cho Commands đọc |

| Platform | Behavior |
|---|---|
| **macOS** | Menu bar đầy đủ + keyboard shortcuts |
| **iPad + keyboard** | Keyboard shortcuts + discoverability overlay (giữ ⌘) |
| **iPhone** | Không hiển thị — cần UI alternative |

---

`.commands` là modifier trên **Scene** (không phải View) để customise menu bar trên macOS và keyboard shortcuts trên iPad, Huy. Ba điểm cốt lõi:

**Phân tích đoạn code:** `.commands` gắn lên `WindowGroup` (Scene level). `SidebarCommands()` là built-in — tự động thêm "View > Toggle Sidebar" vào menu bar, hoạt động cùng `NavigationSplitView`. `RecipeCommands()` là custom struct conform `Commands` protocol — developer tự định nghĩa menu items, keyboard shortcuts, enable/disable logic.

**Ba cách tạo commands:** `CommandMenu("Name")` tạo menu **hoàn toàn mới** trên menu bar (ví dụ: menu "Recipes"). `CommandGroup(after: .newItem)` thêm items vào menu **có sẵn** (File, Edit, View...) tại vị trí chỉ định. `CommandGroup(replacing: .help)` **thay thế hoàn toàn** một menu group.

**`@FocusedValue` / `@FocusedBinding` là cầu nối quan trọng nhất.** Commands sống ở Scene level nhưng cần tương tác với data ở View level (recipe đang edit là gì? có thể delete không?). View publish data qua `.focusedSceneValue(\.recipe, $recipe)`, Commands đọc qua `@FocusedBinding(\.recipe) var recipe`. Khi không có view nào publish → `recipe == nil` → menu items disabled (grayed out). Khi user focus vào RecipeEditor → recipe có giá trị → menu items enabled. Cơ chế này đảm bảo menu bar luôn reflect đúng context hiện tại.
