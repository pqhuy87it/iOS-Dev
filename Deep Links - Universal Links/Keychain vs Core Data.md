# Keychain vs Core Data — không phải là sự thay thế

Câu trả lời ngắn: **không, Core Data không tốt hơn Keychain cho use case này** — vì hai cái được thiết kế cho hai mục đích hoàn toàn khác nhau. So sánh chúng giống như so sánh **két sắt** với **tủ tài liệu**: két sắt nhỏ nhưng an toàn cho thứ quý, tủ tài liệu rộng nhưng không khoá được.

## 1. Bản chất khác nhau

| Khía cạnh | Keychain | Core Data |
|---|---|---|
| Mục đích thiết kế | Lưu trữ secret (token, password, key, cert) | Object graph + persistence cho structured data |
| Backing storage | Encrypted DB do Security framework quản lý, có thể tích hợp Secure Enclave | SQLite file (mặc định) trong app sandbox |
| Encryption | **Hardware-backed encryption** mặc định, theo `kSecAttrAccessible` class | **Không mã hóa mặc định** — chỉ có iOS Data Protection (file-level) |
| Kích thước phù hợp | Nhỏ (thường < vài KB/item) | Lớn (MB-GB), nhiều records, có relationship |
| Query | Lookup theo attributes, không có relationship | Predicate phức tạp, fetch request, NSFetchedResultsController |
| Survive uninstall | iOS 10.3+ bị wipe (trước đó thì không) — có thể config qua Access Group + iCloud Keychain | Luôn bị wipe |
| Threading model | Thread-safe, atomic per item | Cần manage `NSManagedObjectContext` cẩn thận, dễ crash nếu sai thread |
| Backup | Không backup vào iCloud/iTunes nếu dùng `...ThisDeviceOnly` | Backup theo file protection setting |

## 2. Tại sao activation token PHẢI ở Keychain

Activation token có 3 đặc tính quyết định:

**Là secret** — ai có token thì kích hoạt được account. Nếu attacker dump SQLite file của Core Data (qua jailbreak, qua backup không mã hoá, qua malware có file access) → token lộ. Trong khi Keychain item với `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` được mã hoá bằng key bind vào device passcode/Secure Enclave, dump file cũng không đọc được.

**Nhỏ và đơn lẻ** — chỉ là string vài chục bytes, không có relationship, không cần query phức tạp. Core Data overkill cho việc lưu một string.

**Cần access control granular** — Keychain hỗ trợ `kSecAttrAccessControl` với biometric (Face ID/Touch ID), `kSecAttrAccessGroup` để share giữa apps cùng team, `accessibility` class để control khi nào item readable (sau first unlock, chỉ khi unlocked, v.v.). Core Data không có gì tương đương ở granularity này.

## 3. Khi nào dùng Core Data trong flow này

Core Data hợp lý nếu pending registration có **structured draft data lớn**: ví dụ form đăng ký nhiều bước, mỗi bước user nhập 20+ fields, có upload ảnh draft, có lưu danh sách interest/preference dạng to-many relationship, hoặc cần `NSFetchedResultsController` để hiện draft list trong UI.

Khi đó architecture đúng là **kết hợp cả hai**:

```
┌─────────────────────────────────────────┐
│ Keychain                                 │
│ - activationToken: String                │
│ - userId: String (sensitive identifier)  │
│ - refreshToken (sau khi activate xong)   │
└─────────────────────────────────────────┘
              │
              │ liên kết qua userId
              ▼
┌─────────────────────────────────────────┐
│ Core Data (hoặc SwiftData)               │
│ Entity: RegistrationDraft                │
│ - userId (non-sensitive)                 │
│ - currentStep                            │
│ - displayName, dateOfBirth, ...          │
│ - avatarLocalPath                        │
│ - interests: to-many relationship        │
│ - createdAt, updatedAt                   │
└─────────────────────────────────────────┘
```

Token và identity bí mật ở Keychain; draft form data không nhạy cảm ở Core Data. Hai store dùng `userId` làm khóa logic để liên kết.

## 4. Với scope của bài toán activation

Cụ thể với activation flow đã thảo luận, Core Data **không cần thiết** vì:

- Chỉ cần lưu `userId` + `email` + `stepCompleted` + `token` → tổng cộng vài trăm bytes.
- Không có relationship, không có list, không cần query.
- Token là secret → bắt buộc encrypted store.
- Server là single source of truth — local chỉ là cache để resume UX.

→ **Keychain (cho token + userId) + UserDefaults (cho non-sensitive flag như `stepCompleted`)** là đủ. Mang Core Data vào sẽ tốn:

- Setup `NSPersistentContainer`, schema, migration plan.
- Quản lý `NSManagedObjectContext` đúng thread.
- Performance overhead khi launch app (load store).
- Vẫn phải dùng Keychain song song cho token → không giảm complexity.

## 5. Nếu vẫn muốn dùng Core Data, lưu ý security

Trường hợp project đã có Core Data sẵn và muốn lưu thêm thông tin draft, **đừng bao giờ lưu token/password/secret trong Core Data**. Nếu bắt buộc phải lưu, tối thiểu:

- Set file protection: `NSPersistentStoreFileProtectionKey: FileProtectionType.complete` — file chỉ readable khi device unlocked.
- Encrypt field-level trước khi save: dùng CryptoKit AES-GCM với key lưu trong **Keychain** (bạn đã làm pattern này khi học iOS Security).
- Hoặc dùng SQLCipher nếu muốn mã hoá toàn bộ store, nhưng phức tạp.

Tức là cuối cùng vẫn cần Keychain để giữ encryption key — không thoát được khỏi Keychain cho secrets.

## 6. Tổng kết

Câu hỏi nên là **"cái nào lưu cái gì?"**, không phải **"cái nào tốt hơn?"**. Cho activation token cụ thể: Keychain. Cho structured non-sensitive draft data nếu có: Core Data hoặc SwiftData. Cho flag UI nhỏ: UserDefaults. Senior iOS architecture là chọn đúng tool cho đúng concern, không tập trung tất cả vào một storage.
