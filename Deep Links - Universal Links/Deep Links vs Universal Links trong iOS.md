# Deep Links vs Universal Links trong iOS

## 1. Bản chất kỹ thuật

**Deep Links (Custom URL Schemes)** là cơ chế cũ của iOS, dùng custom URL scheme do app đăng ký trong `Info.plist`. Ví dụ: `myapp://product/123`. Khi user tap vào link này, iOS tra cứu app nào đã register scheme `myapp://` rồi mở app đó.

**Universal Links** là cơ chế mới (iOS 9+) của Apple, dùng URL HTTPS chuẩn (ví dụ: `https://example.com/product/123`). Cùng một URL có thể vừa mở app (nếu app đã cài) vừa mở web (nếu chưa cài), không cần URL scheme riêng.

## 2. So sánh chi tiết

| Tiêu chí | Deep Links (URL Scheme) | Universal Links |
|---|---|---|
| Format | `myapp://path` | `https://domain.com/path` |
| iOS version | iOS 2+ | iOS 9+ |
| Setup | Khai báo `CFBundleURLTypes` trong Info.plist | Associated Domains entitlement + file `apple-app-site-association` (AASA) trên server |
| Khi app chưa cài | Báo lỗi "Cannot Open Page" hoặc fail im lặng | Mở Safari → website của bạn (graceful fallback) |
| Conflict giữa các app | Nhiều app có thể register cùng scheme → undefined behavior, app cài sau có thể "cướp" scheme | Không thể bị giả mạo vì cần verify domain ownership qua AASA |
| Security | Yếu — bất kỳ app nào cũng có thể register scheme của bạn | Mạnh — Apple verify ownership qua AASA file trên HTTPS |
| Privacy | Có thể dùng `canOpenURL:` để dò xem app nào đã cài (cần khai báo `LSApplicationQueriesSchemes`) | Không leak thông tin app installed |
| User experience từ Safari | Hiện popup "Open in [App]?" gây khó chịu | Mở app trực tiếp, smooth |
| Hoạt động trong WKWebView | Có | Không (mặc định bị block, phải handle thủ công qua `WKNavigationDelegate`) |
| Hoạt động trong app khác (ví dụ Mail, Messages, Notes) | Hoạt động | Hoạt động |

## 3. Implementation

**Deep Link setup:**

Trong `Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
    </dict>
</array>
```

Handle trong `SceneDelegate` (hoặc `AppDelegate` nếu chưa migrate):
```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    // Parse url.scheme, url.host, url.path
}
```

**Universal Link setup:**

Bước 1: Bật **Associated Domains** capability, thêm `applinks:example.com`.

Bước 2: Upload file `apple-app-site-association` (không có extension) lên `https://example.com/.well-known/apple-app-site-association`. Phải serve qua HTTPS hợp lệ, content-type `application/json`, không redirect:
```json
{
  "applinks": {
    "details": [{
      "appIDs": ["TEAMID.com.example.MyApp"],
      "components": [
        { "/": "/product/*" },
        { "/": "/article/*", "exclude": true }
      ]
    }]
  }
}
```

Bước 3: Handle trong `SceneDelegate`:
```swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else { return }
    // Route theo url.path / url.queryItems
}
```

## 4. Pitfalls thực tế cần lưu ý

**Universal Links bị "broken" sau khi user long-press → "Open in Safari"**: Khi user chủ động chọn mở bằng Safari trên domain Universal Link, iOS sẽ nhớ preference đó và không mở app nữa. Để fix, user phải scroll lên top của trang và tap banner "Open in App" (Smart App Banner), hoặc bạn handle từ trang web bằng cách redirect lại.

**AASA caching aggressive**: iOS cache file AASA, đôi khi đến vài ngày. Nếu test trên simulator/device không thấy update, phải xoá app, restart device. Từ iOS 14+, Apple chuyển sang fetch AASA qua **CDN của Apple** (`app-site-association.cdn-apple.com`), nên có thể có lag thêm. Dùng `swcutil` trên macOS để debug:
```bash
sudo swcutil show --bid com.example.MyApp
```

**Không hoạt động khi gõ URL trực tiếp vào Safari**: Universal Links chỉ trigger khi user **tap** vào link, không trigger khi user **gõ tay** vào address bar. Đây là design intentional của Apple.

**WKWebView không tự động mở Universal Link**: Phải intercept trong `decidePolicyFor navigationAction`, gọi `UIApplication.shared.open(url, options: [.universalLinksOnly: true])`.

**Custom URL Scheme bị deprecate dần**: Apple khuyến khích migrate sang Universal Links. iOS 14+ đã giới hạn nặng `canOpenURL` (max 50 schemes trong `LSApplicationQueriesSchemes`).

## 5. Khi nào dùng cái nào?

Best practice hiện nay là **Universal Links là default**, chỉ dùng Custom URL Scheme cho các use case:
- OAuth callback từ third-party SDK (Google, Facebook) yêu cầu scheme cụ thể.
- Inter-app communication trong cùng team/organization khi không có web domain.
- Internal tooling, dev/debug shortcuts.

Production app thương mại nên dùng Universal Links cho marketing campaigns, email links, push notification deep linking, sharing content — vì SEO benefit (cùng URL hoạt động cả web lẫn app), không bị "Open in App?" prompt, và security tốt hơn.

Trong nhiều dự án thực tế, hai cơ chế này **kết hợp**: Universal Link là entry point chính, còn Custom URL Scheme dùng cho intra-app navigation hoặc OAuth callback. Routing layer (như một `DeepLinkRouter` class) sẽ normalize cả hai loại URL về cùng một format nội bộ trước khi điều hướng.
