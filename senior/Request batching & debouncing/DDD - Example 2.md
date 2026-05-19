# Refactoring HomeScreen theo SOLID

## Phân tích vi phạm hiện tại

```
┌─ HomeScreen (~200 dòng) ──────────────────────────────────┐
│                                                             │
│  S (Single Responsibility) ❌                               │
│  ├─ Push notification routing (switch 6 cases)             │
│  ├─ Data refresh logic (switch 6 cases)                    │
│  ├─ Terms agreement checking                               │
│  ├─ App lifecycle observation                              │
│  ├─ EventBus subscriptions (2 streams)                     │
│  └─ Navigation                                             │
│                                                             │
│  O (Open/Closed) ❌                                         │
│  ├─ Thêm TargetType mới → sửa 2 switch trong HomeScreen   │
│  ├─ Thêm section mới → sửa HomeScreenView Column          │
│  └─ Thêm push type → sửa _handlePushNotification          │
│                                                             │
│  D (Dependency Inversion) ❌                                │
│  ├─ appScreenGlobalKey.currentState!.context ở MỌI NƠI    │
│  ├─ RSA.instance.targetFromPushNotification trực tiếp      │
│  ├─ TermsAgreeService.instance static call                 │
│  └─ ref.invalidate() rải rác cho từng provider             │
│                                                             │
│  Duplicate Pattern (DRY) ❌                                  │
│  ├─ 5 list views copy-paste gần giống nhau                 │
│  ├─ onTapMore / onTapCard pattern lặp lại                  │
│  ├─ TTPFirebaseAnalytics.logEvent boilerplate              │
│  └─ Navigator.push(appScreenGlobalKey...) lặp 20+ lần     │
└─────────────────────────────────────────────────────────────┘
```## Tổng kết từng nguyên tắc SOLID đã áp dụng

### S — Single Responsibility

| Trước | Sau |
|---|---|
| `HomeScreen` xử lý 6+ trách nhiệm | `HomeScreen` chỉ wire + listen lifecycle |
| Push notification routing nằm trong widget | `PushNotificationRouter` class riêng |
| Terms check logic nằm trong widget | `TermsCheckService` class riêng |
| 5 list views copy-paste 80 dòng mỗi cái | `HomeSectionList<T>` generic + config |
| `appScreenGlobalKey.currentState!` rải 20+ chỗ | `AppNavigator` abstraction 1 chỗ |
| WebView flag check duplicate 2 nơi | `BusinessNavigation.resolveScreen()` 1 nơi |

### O — Open/Closed

Trước: thêm `TargetType` mới phải sửa **2 switch statements** trong HomeScreen.

Sau: thêm `TargetType` = tạo 1 class + register:

```dart
class NewTypePushStrategy implements PushNotificationRouteStrategy { ... }

// Thêm vào list strategies — HomeScreen không đổi
strategies: [...existingStrategies, NewTypePushStrategy()],
```

Tương tự `HomeSectionList<T>` — thêm section mới chỉ cần truyền `HomeSectionConfig` khác.

### L — Liskov Substitution

Mọi `PushNotificationRouteStrategy` thay thế được cho nhau:

```dart
// Router không quan tâm strategy cụ thể là gì
final strategy = _strategies[event.targetType];
strategy.refreshData(ref);       // Mọi strategy đều hoạt động
await strategy.navigate(...);    // Không phá vỡ contract
```

### I — Interface Segregation

```dart
// AppNavigator: chỉ methods navigation cần
abstract class AppNavigator {
  void pushScreen(Widget screen);
  void popToFirst();
}

// PushNotificationRouteStrategy: chỉ 2 methods
abstract class PushNotificationRouteStrategy {
  void refreshData(WidgetRef ref);
  Future<void> navigate(...);
}

// Không có "god interface" chứa mọi thứ
```

### D — Dependency Inversion

```dart
// TRƯỚC: 20+ chỗ gọi trực tiếp
appScreenGlobalKey.currentState!.context  // concrete, crash-prone
TermsAgreeService.instance               // static singleton
RSA.instance.targetFromPushNotification  // global state

// SAU: phụ thuộc abstractions
final AppNavigator _navigator;           // injectable, testable
final TermsCheckService _termsService;   // injectable, testable
final List<PushNotificationRouteStrategy> _strategies; // injectable
```

### Kết quả đo lường

```
                              TRƯỚC        SAU
HomeScreen                    ~200 dòng    ~80 dòng
5 list views tổng cộng        ~400 dòng    ~150 dòng (dùng generic)
Push routing switch            2 × 6 cases  0 switch (strategy pattern)
appScreenGlobalKey calls       20+          1 (trong AppNavigator)
Copy-paste business nav logic  2 chỗ        1 (BusinessNavigation)
Thêm push notification type    Sửa 2 files  Tạo 1 file mới
```
