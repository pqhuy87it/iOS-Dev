# Mã hoá trong iOS: AES, RSA, ECC, HMAC từ góc nhìn Senior

Trước khi đi vào từng thuật toán, có một bức tranh tổng thể cần nắm: trong production iOS, anh hiếm khi dùng một thuật toán đơn lẻ. Pattern phổ biến là **hybrid cryptography** — ECC/RSA để trao đổi key, AES để mã hoá data, HMAC (hoặc AEAD như AES-GCM) để authenticate. Hiểu vai trò của từng thuật toán quan trọng hơn nhớ chi tiết toán học.

---

## 1. AES (Advanced Encryption Standard)

### Bản chất

AES là **symmetric block cipher** — cùng một key dùng để mã hoá và giải mã. Block size cố định 128-bit, key size 128/192/256-bit. Trong iOS production hầu như chỉ dùng **AES-256**.

### Cách hoạt động (high-level)

AES hoạt động theo **rounds** (10/12/14 rounds tương ứng với 128/192/256-bit key). Mỗi round gồm 4 bước:

1. **SubBytes** — thay thế byte qua S-box (non-linear, chống linear cryptanalysis)
2. **ShiftRows** — dịch các hàng trong state matrix (diffusion theo chiều ngang)
3. **MixColumns** — trộn các cột qua phép nhân ma trận trong GF(2^8) (diffusion theo chiều dọc)
4. **AddRoundKey** — XOR với round key được derive từ master key qua **key schedule**

Round cuối bỏ MixColumns. Bước SubBytes + MixColumns tạo ra **confusion** và **diffusion** theo định nghĩa Shannon — đây là lý do AES an toàn về mặt toán học.

### Modes of Operation — chỗ này dev hay sai

Block cipher chỉ mã hoá 1 block (16 byte). Để mã hoá data dài hơn, cần **mode**:

| Mode | Đặc điểm | Khi nào dùng |
|------|----------|--------------|
| **ECB** | Mỗi block độc lập | **KHÔNG BAO GIỜ DÙNG** trong production |
| **CBC** | XOR với block trước + IV | Legacy, cần HMAC riêng để authenticate |
| **CTR** | Biến block cipher thành stream cipher | Cần authenticate riêng |
| **GCM** | CTR + GHASH authentication | **Default choice** trong iOS hiện đại |

ECB rò rỉ pattern (ảnh nổi tiếng "ECB penguin"). CBC không có authentication — vulnerable to **padding oracle attack** nếu implement sai. **AES-GCM là AEAD (Authenticated Encryption with Associated Data)** — nó vừa mã hoá vừa generate authentication tag trong một lần, chống tampering.

### Implementation trong iOS với CryptoKit

```swift
import CryptoKit

// Generate key (lưu vào Keychain hoặc derive từ password qua HKDF)
let key = SymmetricKey(size: .bits256)

// Encrypt với AES-GCM
let plaintext = "Sensitive data".data(using: .utf8)!
let sealedBox = try AES.GCM.seal(plaintext, using: key)

// sealedBox.combined chứa nonce + ciphertext + tag
let encrypted = sealedBox.combined!

// Decrypt
let receivedBox = try AES.GCM.SealedBox(combined: encrypted)
let decrypted = try AES.GCM.open(receivedBox, using: key)
```

**Lưu ý senior-level:**
- **Nonce** trong GCM phải **unique** với mỗi message dưới cùng một key. Reuse nonce = catastrophic failure (key có thể bị recover). CryptoKit tự generate random nonce nếu không truyền vào — an toàn nhưng cần biết.
- Limit khuyến nghị: ~2^32 messages cho mỗi key với random nonce (birthday bound).
- Authentication tag 16 byte — không được truncate xuống dưới 12 byte.
- Nếu cần streaming/chunked encryption, dùng **ChaChaPoly** hoặc chia chunk + unique nonce per chunk + chain authentication.

### Performance

AES có **hardware acceleration** trên tất cả Apple Silicon và A-series chip qua AES instruction set. Throughput thường vài GB/s — không phải bottleneck cho bulk data.

---

## 2. RSA (Rivest-Shamir-Adleman)

### Bản chất

RSA là **asymmetric cipher** — có 2 key: public key (mã hoá / verify) và private key (giải mã / sign). Bảo mật dựa trên **integer factorization problem** — cho `n = p × q` với `p, q` là số nguyên tố lớn, không có thuật toán hiệu quả nào tìm lại `p, q`.

### Math cơ bản

```
Key generation:
  - Chọn 2 prime p, q (mỗi cái ~1024-bit cho RSA-2048)
  - n = p × q                        (modulus)
  - φ(n) = (p-1)(q-1)                (Euler totient)
  - Chọn e (thường 65537)            (public exponent)
  - d = e^(-1) mod φ(n)              (private exponent)
  
Public key:  (n, e)
Private key: (n, d)

Encrypt:  c = m^e mod n
Decrypt:  m = c^d mod n

Sign:     s = H(m)^d mod n
Verify:   H(m) ?= s^e mod n
```

### Padding — bắt buộc phải hiểu

RSA "raw" (textbook RSA) **không an toàn**. Phải dùng padding:

- **PKCS#1 v1.5** — legacy, có Bleichenbacher attack nếu implement sai. Vẫn còn nhiều system dùng.
- **OAEP (Optimal Asymmetric Encryption Padding)** — chuẩn hiện đại cho encryption.
- **PSS (Probabilistic Signature Scheme)** — chuẩn hiện đại cho signing.

### Implementation trong iOS

RSA không có trong CryptoKit (Apple cố tình hướng dev sang ECC). Phải dùng **Security framework**:

```swift
import Security

// Generate RSA key pair
let attributes: [String: Any] = [
    kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
    kSecAttrKeySizeInBits as String: 2048,
    kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: "com.app.rsa.private".data(using: .utf8)!
    ]
]

var error: Unmanaged<CFError>?
guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
    throw error!.takeRetainedValue() as Error
}
let publicKey = SecKeyCopyPublicKey(privateKey)!

// Encrypt với OAEP
let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
let ciphertext = SecKeyCreateEncryptedData(publicKey, algorithm, plaintext as CFData, &error)

// Sign với PSS
let signAlgo: SecKeyAlgorithm = .rsaSignatureMessagePSSSHA256
let signature = SecKeyCreateSignature(privateKey, signAlgo, data as CFData, &error)
```

### Hạn chế thực tế

- **Chậm**: encrypt/sign tốn ~10^5 lần CPU so với AES. Không bao giờ encrypt bulk data bằng RSA.
- **Limit size**: RSA-2048 với OAEP-SHA256 chỉ mã hoá được tối đa ~190 byte. Pattern chuẩn: dùng RSA encrypt một AES key, AES encrypt data thực.
- **Key size lớn**: RSA-2048 = 256 byte. RSA-3072 (tương đương AES-128 security) = 384 byte. RSA-4096 đang dần thành chuẩn cho high-security.
- **Quantum threat**: Shor's algorithm phá được RSA. Trong 10-15 năm tới sẽ phải migration sang post-quantum.

**Senior tip**: trong iOS app mới, **default nên dùng ECC**. Chỉ dùng RSA khi bắt buộc interop với backend/standard (X.509 certs, JWT RS256, legacy server).

---

## 3. ECC (Elliptic Curve Cryptography)

### Bản chất

ECC dựa trên **elliptic curve discrete logarithm problem (ECDLP)** — trên một elliptic curve, cho 2 điểm `P` và `Q = k·P`, không có cách hiệu quả tìm `k`. Vấn đề này khó hơn integer factorization với cùng key size, nên ECC dùng key ngắn hơn nhiều.

### So sánh strength

| Symmetric (AES) | RSA | ECC |
|-----------------|-----|-----|
| 128-bit | 3072-bit | 256-bit |
| 256-bit | 15360-bit | 512-bit |

ECC-256 ≈ RSA-3072 về độ an toàn nhưng key chỉ 32 byte và operation nhanh hơn ~10x.

### Các curves quan trọng trong iOS

- **P-256 (secp256r1 / NIST P-256)** — duy nhất được Secure Enclave hỗ trợ. Dùng cho production có hardware-backed key.
- **P-384, P-521** — high-security, không có Secure Enclave support.
- **Curve25519** — modern, được thiết kế bởi Daniel J. Bernstein, không có "magic constants" nghi ngờ như NIST curves. CryptoKit support qua `Curve25519`.

### 2 thuật toán chính trên ECC

**ECDH (Elliptic Curve Diffie-Hellman)** — key agreement:

```swift
// Cả 2 bên đều generate keypair
let alicePrivate = P256.KeyAgreement.PrivateKey()
let bobPrivate = P256.KeyAgreement.PrivateKey()

// Trao đổi public key, sau đó mỗi bên compute shared secret
let sharedSecret = try alicePrivate.sharedSecretFromKeyAgreement(
    with: bobPrivate.publicKey
)

// Derive symmetric key qua HKDF (đừng dùng shared secret trực tiếp)
let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: salt,
    sharedInfo: Data("AES-GCM-Encryption".utf8),
    outputByteCount: 32
)
```

**ECDSA (Elliptic Curve Digital Signature Algorithm)** — signing:

```swift
// Generate signing key trong Secure Enclave (hardware-backed)
let privateKey = try SecureEnclave.P256.Signing.PrivateKey()

// Sign
let signature = try privateKey.signature(for: data)

// Verify (chỉ cần public key)
let isValid = privateKey.publicKey.isValidSignature(signature, for: data)
```

### Secure Enclave specifics

Theo context anh đã làm với Secure Enclave: chỉ **P-256 signing/key-agreement private key** được tạo bên trong Enclave. Private key **không bao giờ rời khỏi chip** — operation xảy ra trong Enclave, anh chỉ nhận được kết quả. Đây là biggest practical security guarantee mà iOS cung cấp.

Limitation: không thể encrypt trực tiếp bằng ECC. Pattern là:
1. ECDH để derive shared key giữa device và server
2. AES-GCM encrypt data với key đó

### Ed25519 — đáng nhắc thêm

Cho signing thuần (không phải key agreement), **Ed25519** là lựa chọn modern hơn ECDSA — deterministic, không cần RNG cho mỗi signature, ít footgun. CryptoKit support qua `Curve25519.Signing`.

---

## 4. HMAC (Hash-based Message Authentication Code)

### Bản chất

HMAC trả lời câu hỏi: **"data này có bị sửa đổi không, và có đúng đến từ người có shared key không?"** Nó là **MAC (Message Authentication Code)** — đảm bảo integrity + authenticity, nhưng không phải confidentiality.

### Tại sao không dùng hash thuần?

Nếu chỉ làm `tag = SHA256(key || message)`, có **length extension attack** — attacker có thể append data và tạo tag hợp lệ mà không biết key (đối với Merkle-Damgård hashes như SHA-1/SHA-256).

HMAC giải quyết bằng cấu trúc 2 lớp:

```
HMAC(K, m) = H( (K ⊕ opad) || H( (K ⊕ ipad) || m ) )

ipad = 0x36 repeated
opad = 0x5C repeated
```

Cấu trúc này được chứng minh là **PRF** (pseudo-random function) dưới giả định hash function compresion function là PRF — security proof rất mạnh.

### Implementation trong iOS

```swift
import CryptoKit

let key = SymmetricKey(size: .bits256)
let message = "Important payload".data(using: .utf8)!

// Generate MAC
let mac = HMAC<SHA256>.authenticationCode(for: message, using: key)

// Verify (luôn dùng API này, không tự so sánh bằng ==)
let isValid = HMAC<SHA256>.isValidAuthenticationCode(
    mac,
    authenticating: message,
    using: key
)
```

### Constant-time comparison — chỗ critical

**Không bao giờ** so sánh MAC bằng `==`:

```swift
// ❌ SAI - vulnerable to timing attack
if computedMAC == receivedMAC { ... }

// ✅ ĐÚNG - CryptoKit's isValidAuthenticationCode constant-time
HMAC<SHA256>.isValidAuthenticationCode(receivedMAC, ...)
```

`Data ==` so sánh byte-by-byte và **return sớm** khi gặp byte khác — attacker đo response time có thể recover MAC từng byte một. CryptoKit's verify API tự xử lý constant-time.

### Use cases trong iOS

1. **API request signing** (kiểu AWS Signature v4) — server và client share secret, mọi request có HMAC header.
2. **Webhook verification** — Stripe, GitHub webhooks đều dùng HMAC-SHA256.
3. **JWT HS256** — symmetric JWT signing.
4. **HKDF** — Key derivation function được xây trên HMAC.
5. **Encrypt-then-MAC** — pattern cũ kết hợp AES-CBC + HMAC. Hiện nay thay bằng AES-GCM.

### HMAC vs AEAD

Câu hỏi senior hay gặp: "Có cần HMAC riêng khi đã dùng AES-GCM không?"
- **Không**, AES-GCM đã authenticate. Thêm HMAC là thừa và có thể tạo bug.
- HMAC còn dùng được khi data **không cần mã hoá** mà chỉ cần verify integrity (ví dụ: signed URL, webhook payload đã ở plaintext).

---

## Tổng kết — Decision tree thực tế

Khi design security feature trong iOS app, anh có thể follow logic này:

- **Encrypt data tại rest hoặc in transit** → AES-GCM (CryptoKit), key lưu Keychain
- **Cần password-based encryption** → PBKDF2/Argon2 để derive key → AES-GCM
- **2 bên cần share secret qua network** → ECDH (P-256 hoặc Curve25519) → HKDF → AES-GCM
- **Sign data, prove authenticity** → ECDSA hoặc Ed25519 (asymmetric); HMAC nếu có shared secret
- **Hardware-backed key** → Secure Enclave P-256
- **Interop với legacy/backend cụ thể** → có thể buộc dùng RSA (OAEP cho encrypt, PSS cho sign)
- **Verify webhook/API integrity** → HMAC-SHA256 với constant-time compare

Nếu anh muốn em đào sâu vào phần nào — ví dụ implementation pattern hoàn chỉnh của hybrid encryption, key rotation strategy, hoặc cách design certificate pinning kết hợp với mấy thuật toán này — em viết tiếp.
