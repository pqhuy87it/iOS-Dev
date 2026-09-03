## Can you give some examples of where singletons might be a good idea?

### Suggested approach: It’s very unlikely you’ll join a company where singletons are used extensively, so feel free to say that broadly speaking singletons aren’t great. 
Once you’ve given up that proviso, perhaps mention that Apple uses them extensively – thinks like UIApplication, for example, are designed to exist only once. 
Finally, try to give a fresh example of your own, such as creating an app-wide logger.

---

## Câu hỏi thực sự đang hỏi gì?

Bề mặt: "cho ví dụ singleton hợp lý". Thực chất interviewer đang test 3 thứ:

1. **Bạn có nhận ra singleton là code smell không?** — Người mới thường trả lời hào hứng "singleton tiện lắm, dùng cho network manager, user session…" → lộ ra chưa từng bị đau vì nó (khó test, hidden dependency, shared mutable state, thread safety).
2. **Nhưng bạn có đủ nuance để không bài trừ mù quáng?** — Trả lời "singleton luôn xấu" cũng trượt. Interviewer muốn thấy bạn phân biệt được *khi nào* nó đúng.
3. **Bạn có biết Apple SDK dùng nó ở đâu và vì sao?** — Kiểm tra hiểu biết nền tảng, không chỉ học lý thuyết OOP chung chung.

Cái "suggested approach" đang gợi ý một khuôn trả lời 3 nhịp: **proviso → ví dụ từ SDK → ví dụ của riêng bạn**. Rồi bonus là so sánh với `Environment` của SwiftUI.

## Vì sao trình tự đó lại quan trọng

Nhịp "proviso" đặt trước có tác dụng tâm lý: nó cho interviewer biết bạn *không* phải người sẽ rắc `.shared` khắp codebase của họ. Sau khi đã trấn an được, các ví dụ bạn đưa ra sẽ được đọc như "biết chọn chỗ dùng", chứ không phải "thích dùng".

## Khung trả lời

**Nhịp 1 — Đặt lập trường (10–15s)**

Nói thẳng: singleton nói chung không tốt, và nêu *lý do cụ thể* thay vì nói chung chung. Ba lý do đủ mạnh:

- **Hidden dependency**: signature của hàm không nói gì về việc nó phụ thuộc `Analytics.shared` → đọc code không biết nó chạm vào cái gì.
- **Khó test**: không inject được fake/mock, state rò rỉ giữa các test case, test order-dependent.
- **Shared mutable state + concurrency**: với Swift Concurrency ngày nay, một singleton mutable buộc bạn phải `@MainActor`, `actor`, hoặc lock — nếu không thì data race.

**Nhịp 2 — Nhưng Apple dùng khắp nơi, và có lý**

Điểm chung của những cái Apple làm singleton: chúng **đại diện cho một tài nguyên vốn dĩ chỉ tồn tại một bản trong hệ thống** — không phải "để cho tiện".

| Singleton | Vì sao chỉ một |
|---|---|
| `UIApplication.shared` | Một process = một app instance, do UIKit khởi tạo |
| `FileManager.default` | Một file system |
| `UNUserNotificationCenter.current()` | Một registration point với hệ thống |
| `UIDevice.current` | Một thiết bị |
| `NotificationCenter.default` | Một bus mặc định (nhưng bạn *vẫn* tạo được instance riêng) |

Chi tiết đáng ghi điểm: `FileManager.default` và `NotificationCenter.default` không phải singleton *thuần* — Apple để bạn `FileManager()`, `NotificationCenter()`. Đó là "shared instance for convenience", khác với `UIApplication` là singleton cưỡng chế (init nó sẽ crash/assert). Phân biệt được hai loại này cho thấy bạn đọc kỹ SDK.

**Nhịp 3 — Ví dụ của riêng bạn**

Gợi ý trong đề là app-wide logger. Vì sao logger là ví dụ tốt: nó **stateless về mặt logic nghiệp vụ** (chỉ ghi ra ngoài), **không ai cần mock nó để test business logic**, và **ghi vào một sink duy nhất** (file/console/remote) nên việc serialize ghi qua một instance là hợp lý.

Vài ví dụ khác cùng chất:
- Một cache/pool bọc tài nguyên hữu hạn (ví dụ `URLCache.shared`, connection pool) — bản chất tài nguyên là một.
- Wrapper cho Keychain: bản thân Keychain là một store duy nhất của hệ thống.
- Feature flag store đọc-only sau khi bootstrap.

Và nói rõ **anti-example** — chỗ mọi người thường lạm dụng: `NetworkManager.shared`, `UserSession.shared`, `DatabaseManager.shared`. Những cái này có state, có behavior cần thay trong test, và bạn *sẽ* muốn hai instance (staging vs production, hai user trên iPad). Chúng nên là dependency được inject; nếu muốn "chỉ tạo một lần" thì đó là việc của DI container hoặc composition root, không phải của chính class đó.

Đây là câu chốt mạnh nhất cho cả câu trả lời:

> "Singleton trộn hai thứ không liên quan: *chỉ có một instance* và *ai cũng truy cập được từ mọi nơi*. Cái thứ nhất thường hợp lý; cái thứ hai mới là nguồn gốc của đau khổ. Nếu tôi cần một instance duy nhất, tôi tạo nó một lần ở composition root rồi inject — giữ được tính duy nhất mà không tạo global access point."

## Bonus: so sánh với SwiftUI Environment

Đây là chỗ ăn điểm, vì nó cho thấy bạn hiểu Environment như một *giải pháp cho vấn đề singleton*, chứ không chỉ là API.

**Điểm giống**: cả hai giải quyết cùng bài toán — làm sao để một dependency dùng chung tới được chỗ cần nó mà không phải truyền thủ công qua 10 tầng init.

**Điểm khác — và đây là phần quan trọng:**

- **Scope**: singleton là global, đúng một giá trị cho cả process, vĩnh viễn. Environment có **scope theo view hierarchy** — bạn override tại bất kỳ subtree nào. Preview inject fake, test inject stub, một nửa app dùng config khác — tất cả không cần đụng tới phần còn lại.
- **Explicit vs hidden**: `@Environment(\.myService) private var service` **hiện trong khai báo của type**. Đọc struct là biết nó phụ thuộc gì. `MyService.shared` gọi giữa thân hàm thì không.
- **Lifetime**: singleton sống mãi. Environment value gắn với hierarchy, đi theo lifecycle của view.
- **Đánh đổi**: Environment không type-safe bằng constructor injection — quên `.environment(...)` thì bạn nhận default value và lỗi chỉ lộ ra ở runtime. Đó là lý do Apple bắt bạn khai báo default trong `EnvironmentKey`.

Câu gói lại: *"Environment thực chất là dependency injection có scope, được ngôn ngữ và framework hỗ trợ. Nó cho tôi sự thuận tiện của singleton mà không mất khả năng thay thế — nên với dependency ở tầng UI, tôi chọn Environment; singleton tôi chỉ để dành cho những thứ mà 'một bản' là sự thật của hệ thống, không phải quyết định thiết kế của tôi."*

Nếu interviewer nghiêng về SwiftUI hiện đại, có thể thêm: từ iOS 17 `@Observable` thay `ObservableObject`, và `.environment(myObject)` inject theo type — làm pattern này gọn hơn nữa, càng ít lý do để với tới `.shared`.

## Câu hỏi đào sâu có thể theo sau

Chuẩn bị sẵn 4 câu này, chúng gần như chắc chắn xuất hiện nếu bạn trả lời tốt:

1. **"Làm sao viết một singleton thread-safe trong Swift?"** → `static let shared` được đảm bảo lazy + thread-safe bởi runtime (dùng `swift_once`). Nhưng đó chỉ an toàn cho *việc khởi tạo*; state bên trong vẫn cần `actor`, `@MainActor`, hoặc serial queue. Với Swift 6 strict concurrency, `static let shared` yêu cầu type phải `Sendable` — nếu không sẽ báo lỗi compile, và đây là lúc nhiều người mới nhận ra singleton mutable của mình vốn đã unsafe từ đầu.
2. **"Bạn test code phụ thuộc singleton thế nào?"** → Rút ra protocol, singleton chỉ là *một* implementation; hoặc thêm cơ chế cho phép thay thế instance trong test; hoặc dùng approach kiểu `@TaskLocal`/dependency container. Nhưng nói thật lòng: cách tốt nhất là refactor để không phụ thuộc trực tiếp.
3. **"`static func` vs singleton, khác gì?"** → static method không giữ state và không implement protocol được → không thay thế được trong test. Singleton là object nên có thể conform protocol, có thể inject. Nếu logic thuần túy stateless, static function lại đơn giản hơn.
4. **"Singleton khác global variable ở đâu?"** → Về tác hại thì gần như giống nhau. Singleton chỉ thêm được lazy initialization và kiểm soát điểm khởi tạo. Đừng nghĩ đóng gói thành `.shared` là đã "sửa" được global state.

## Bẫy nên tránh

- Đừng nói singleton "vi phạm SOLID" rồi dừng lại — phải chỉ được *nguyên tắc nào* và *bằng cách nào*. Chủ yếu là Dependency Inversion (module cấp cao phụ thuộc trực tiếp vào implementation cụ thể) và Single Responsibility (class tự quản lý lifecycle của chính nó, ngoài việc làm đúng nhiệm vụ nghiệp vụ).
- Đừng liệt kê 8 ví dụ. Hai ví dụ từ SDK + một của bạn là đủ; sâu hơn tốt hơn nhiều.
- Đừng nói "tôi không bao giờ dùng singleton" nếu codebase của bạn có — interviewer hay hỏi tiếp "vậy dự án gần nhất của bạn có cái nào?".
