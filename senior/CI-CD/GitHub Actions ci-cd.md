# GitHub Actions CI/CD cho Dự án iOS

Huy, đây là hướng dẫn chi tiết từ setup cơ bản đến production-grade pipeline cho iOS.

---

## 1. Kiến trúc tổng quan

Một pipeline CI/CD iOS điển hình gồm các stage chính: **Build → Test → Code Quality → Archive → Distribute**. GitHub Actions chạy trên macOS runner (`macos-14` hoặc `macos-15`) vì cần Xcode để build.

Cấu trúc thư mục thường dùng:

```
.github/
├── workflows/
│   ├── ci.yml              # PR checks
│   ├── release.yml         # Production release
│   └── nightly.yml         # Nightly build (optional)
├── actions/
│   └── setup-ios/
│       └── action.yml      # Composite action dùng chung
```

```
# .github/workflows/ci.yml
name: iOS CI

on:
  pull_request:
    branches: [main, develop]
    paths:
      - '**/*.swift'
      - '**/*.xib'
      - '**/*.storyboard'
      - '*.xcodeproj/**'
      - '*.xcworkspace/**'
      - 'Podfile*'
      - 'Package.swift'
      - '.github/workflows/ci.yml'
  push:
    branches: [main, develop]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true  # Hủy run cũ khi có push mới

env:
  SCHEME: "MyApp"
  PROJECT: "MyApp.xcodeproj"       # hoặc WORKSPACE: "MyApp.xcworkspace"
  DESTINATION: "platform=iOS Simulator,name=iPhone 16,OS=18.0"
  XCODE_VERSION: "16.0"
  DERIVED_DATA: "build/DerivedData"

jobs:
  # ─── JOB 1: Build & Test ───────────────────────────────────
  build-and-test:
    name: 🔨 Build & Test
    runs-on: macos-15
    timeout-minutes: 30

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app

      - name: Show Xcode version
        run: xcodebuild -version

      # ── Cache SPM packages ──
      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: |
            ${{ env.DERIVED_DATA }}/SourcePackages
            ~/Library/Caches/org.swift.swiftpm
          key: spm-${{ runner.os }}-${{ hashFiles('**/Package.resolved') }}
          restore-keys: spm-${{ runner.os }}-

      # ── Cache CocoaPods (nếu dùng) ──
      # - name: Cache Pods
      #   uses: actions/cache@v4
      #   with:
      #     path: Pods
      #     key: pods-${{ runner.os }}-${{ hashFiles('Podfile.lock') }}
      #     restore-keys: pods-${{ runner.os }}-
      # - name: Install Pods
      #   run: pod install --repo-update

      # ── Build ──
      - name: Build
        run: |
          xcodebuild build-for-testing \
            -project "${{ env.PROJECT }}" \
            -scheme "${{ env.SCHEME }}" \
            -destination "${{ env.DESTINATION }}" \
            -derivedDataPath "${{ env.DERIVED_DATA }}" \
            -enableCodeCoverage YES \
            -resultBundlePath "build/Build.xcresult" \
            CODE_SIGNING_ALLOWED=NO \
            | xcbeautify --renderer github-actions

      # ── Test ──
      - name: Run Tests
        run: |
          xcodebuild test-without-building \
            -project "${{ env.PROJECT }}" \
            -scheme "${{ env.SCHEME }}" \
            -destination "${{ env.DESTINATION }}" \
            -derivedDataPath "${{ env.DERIVED_DATA }}" \
            -enableCodeCoverage YES \
            -resultBundlePath "build/Test.xcresult" \
            | xcbeautify --renderer github-actions

      # ── Code Coverage Report ──
      - name: Generate Coverage Report
        if: success()
        run: |
          xcrun xccov view --report --json \
            "build/Test.xcresult" > build/coverage.json

      - name: Check Minimum Coverage (80%)
        if: success()
        run: |
          COVERAGE=$(python3 -c "
          import json
          with open('build/coverage.json') as f:
              data = json.load(f)
          # Lấy line coverage tổng
          print(f'{data[\"lineCoverage\"] * 100:.1f}')
          ")
          echo "📊 Code Coverage: ${COVERAGE}%"
          if (( $(echo "$COVERAGE < 80.0" | bc -l) )); then
            echo "::error::Coverage ${COVERAGE}% is below minimum 80%"
            exit 1
          fi

      # ── Upload Artifacts ──
      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: build/Test.xcresult
          retention-days: 7

  # ─── JOB 2: SwiftLint ─────────────────────────────────────
  lint:
    name: 🧹 SwiftLint
    runs-on: macos-15
    timeout-minutes: 5

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run SwiftLint
        run: |
          if command -v swiftlint &> /dev/null; then
            swiftlint lint --reporter github-actions-logging --strict
          else
            brew install swiftlint
            swiftlint lint --reporter github-actions-logging --strict
          fi

  # ─── JOB 3: Periphery (Dead Code Detection) ───────────────
  periphery:
    name: 🔍 Dead Code Check
    runs-on: macos-15
    timeout-minutes: 15
    # Chỉ chạy trên PR, không block merge
    if: github.event_name == 'pull_request'
    continue-on-error: true

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app

      - name: Install Periphery
        run: brew install peripheryapp/periphery/periphery

      - name: Scan Dead Code
        run: |
          periphery scan \
            --project "${{ env.PROJECT }}" \
            --schemes "${{ env.SCHEME }}" \
            --targets "${{ env.SCHEME }}" \
            --format github-actions
```

```
# .github/workflows/release.yml
name: iOS Release

on:
  push:
    tags:
      - 'v*'           # Trigger khi push tag: v1.0.0, v1.2.3-beta.1
  workflow_dispatch:    # Cho phép trigger thủ công
    inputs:
      environment:
        description: 'Deploy environment'
        required: true
        default: 'testflight'
        type: choice
        options:
          - testflight
          - app-store

env:
  SCHEME: "MyApp"
  PROJECT: "MyApp.xcodeproj"
  XCODE_VERSION: "16.0"
  DERIVED_DATA: "build/DerivedData"
  ARCHIVE_PATH: "build/MyApp.xcarchive"
  IPA_PATH: "build/MyApp.ipa"
  KEYCHAIN_NAME: "build.keychain"
  KEYCHAIN_PASSWORD: "temporary_password"  # Chỉ tồn tại trong CI run

jobs:
  release:
    name: 🚀 Build & Release
    runs-on: macos-15
    timeout-minutes: 45
    environment: ${{ github.event.inputs.environment || 'testflight' }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app

      # ═══════════════════════════════════════════════════════
      # BƯỚC 1: Setup Code Signing (quan trọng nhất!)
      # ═══════════════════════════════════════════════════════
      
      # Cách 1: Manual certificate + provisioning profile
      - name: Install Apple Certificate
        env:
          P12_BASE64: ${{ secrets.APPLE_CERTIFICATE_P12 }}
          P12_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
        run: |
          # Tạo keychain tạm
          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
          security set-keychain-settings -lut 21600 "$KEYCHAIN_NAME"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
          
          # Import certificate
          echo "$P12_BASE64" | base64 --decode > /tmp/certificate.p12
          security import /tmp/certificate.p12 \
            -k "$KEYCHAIN_NAME" \
            -P "$P12_PASSWORD" \
            -T /usr/bin/codesign \
            -T /usr/bin/security
          
          # Cho phép codesign truy cập keychain
          security set-key-partition-list -S apple-tool:,apple: \
            -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
          
          # Thêm vào search list
          security list-keychains -d user -s "$KEYCHAIN_NAME" login.keychain-db
          
          # Cleanup
          rm /tmp/certificate.p12

      - name: Install Provisioning Profile
        env:
          PROVISIONING_PROFILE_BASE64: ${{ secrets.PROVISIONING_PROFILE }}
        run: |
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          echo "$PROVISIONING_PROFILE_BASE64" | base64 --decode \
            > ~/Library/MobileDevice/Provisioning\ Profiles/build.mobileprovision

      # ═══════════════════════════════════════════════════════
      # BƯỚC 2: Version Bump (từ git tag)
      # ═══════════════════════════════════════════════════════
      - name: Set Version from Tag
        if: startsWith(github.ref, 'refs/tags/v')
        run: |
          VERSION="${GITHUB_REF#refs/tags/v}"
          # Tách version và build number: v1.2.3 → 1.2.3
          MARKETING_VERSION=$(echo "$VERSION" | sed 's/-.*//')
          BUILD_NUMBER=${{ github.run_number }}
          
          echo "VERSION=$MARKETING_VERSION" >> $GITHUB_ENV
          echo "BUILD_NUMBER=$BUILD_NUMBER" >> $GITHUB_ENV
          echo "📦 Version: $MARKETING_VERSION ($BUILD_NUMBER)"

      # ═══════════════════════════════════════════════════════
      # BƯỚC 3: Archive
      # ═══════════════════════════════════════════════════════
      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: |
            ${{ env.DERIVED_DATA }}/SourcePackages
            ~/Library/Caches/org.swift.swiftpm
          key: spm-${{ runner.os }}-${{ hashFiles('**/Package.resolved') }}

      - name: Archive
        run: |
          xcodebuild archive \
            -project "${{ env.PROJECT }}" \
            -scheme "${{ env.SCHEME }}" \
            -configuration Release \
            -destination "generic/platform=iOS" \
            -archivePath "${{ env.ARCHIVE_PATH }}" \
            -derivedDataPath "${{ env.DERIVED_DATA }}" \
            MARKETING_VERSION="${{ env.VERSION }}" \
            CURRENT_PROJECT_VERSION="${{ env.BUILD_NUMBER }}" \
            | xcbeautify

      # ═══════════════════════════════════════════════════════
      # BƯỚC 4: Export IPA
      # ═══════════════════════════════════════════════════════
      - name: Create ExportOptions.plist
        run: |
          cat > build/ExportOptions.plist << 'EOF'
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
            "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>method</key>
            <string>app-store</string>
            <key>destination</key>
            <string>upload</string>
            <key>signingStyle</key>
            <string>manual</string>
            <key>provisioningProfiles</key>
            <dict>
              <key>com.company.myapp</key>
              <string>MyApp Distribution Profile</string>
            </dict>
            <key>uploadSymbols</key>
            <true/>
            <key>compileBitcode</key>
            <false/>
          </dict>
          </plist>
          EOF

      - name: Export IPA
        run: |
          xcodebuild -exportArchive \
            -archivePath "${{ env.ARCHIVE_PATH }}" \
            -exportOptionsPlist "build/ExportOptions.plist" \
            -exportPath "build/Export" \
            | xcbeautify

      # ═══════════════════════════════════════════════════════
      # BƯỚC 5: Upload to TestFlight / App Store Connect
      # ═══════════════════════════════════════════════════════
      - name: Upload to App Store Connect
        env:
          APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          APP_STORE_CONNECT_API_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY: ${{ secrets.ASC_PRIVATE_KEY }}
        run: |
          # Tạo AuthKey file
          mkdir -p ~/.private_keys
          echo "$APP_STORE_CONNECT_API_KEY" > \
            ~/.private_keys/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8
          
          xcrun altool --upload-app \
            --type ios \
            --file "build/Export/MyApp.ipa" \
            --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
            --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"

      # ═══════════════════════════════════════════════════════
      # BƯỚC 6: Cleanup (luôn chạy)
      # ═══════════════════════════════════════════════════════
      - name: Cleanup Keychain
        if: always()
        run: |
          security delete-keychain "$KEYCHAIN_NAME" 2>/dev/null || true
          rm -f ~/Library/MobileDevice/Provisioning\ Profiles/build.mobileprovision
          rm -rf ~/.private_keys

      # ═══════════════════════════════════════════════════════
      # BƯỚC 7: Notify
      # ═══════════════════════════════════════════════════════
      - name: Create GitHub Release
        if: startsWith(github.ref, 'refs/tags/v')
        uses: softprops/action-gh-release@v2
        with:
          files: build/Export/MyApp.ipa
          generate_release_notes: true

      - name: Notify Slack
        if: always()
        uses: slackapi/slack-github-action@v2
        with:
          webhook: ${{ secrets.SLACK_WEBHOOK }}
          webhook-type: incoming-webhook
          payload: |
            {
              "text": "${{ job.status == 'success' && '✅' || '❌' }} iOS ${{ env.VERSION }} (${{ env.BUILD_NUMBER }}) — ${{ job.status }}"
            }
```

---

## 2. CI Workflow — Pull Request Checks### Giải thích các điểm quan trọng trong CI:

**`concurrency`** — Khi push commit mới vào cùng branch/PR, run cũ tự động bị cancel, tiết kiệm runner minutes.

**`paths` filter** — Chỉ trigger khi file liên quan thay đổi, tránh chạy CI khi chỉ sửa README.

**`build-for-testing` + `test-without-building`** — Tách riêng 2 bước giúp dễ debug. Nếu build fail thì không cần chờ test timeout.

**`CODE_SIGNING_ALLOWED=NO`** — Bỏ qua code signing khi chạy CI trên simulator, tránh lỗi provisioning profile.

**`xcbeautify`** — Format output xcodebuild thành GitHub Actions annotation, hiện warning/error trực tiếp trên PR diff.

---

## 3. Release Workflow — Build & Distribute---

## 4. Phương án thay thế với Fastlane

Nếu dự án đã dùng Fastlane, workflow sẽ gọn hơn rất nhiều vì Fastlane xử lý code signing (via `match`) và upload:

```yaml
# Trong release job, thay thế các bước 1-5 bằng:
- name: Setup Ruby
  uses: ruby/setup-ruby@v1
  with:
    ruby-version: '3.2'
    bundler-cache: true   # Cache gems tự động

- name: Build & Upload
  env:
    MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
    MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_TOKEN }}
    APP_STORE_CONNECT_API_KEY_JSON: ${{ secrets.ASC_API_KEY_JSON }}
  run: |
    bundle exec fastlane release   # hoặc beta, adhoc, etc.
```

Với `Fastfile` tương ứng:

```ruby
# fastlane/Fastfile
default_platform(:ios)

platform :ios do
  before_all do
    setup_ci   # Quan trọng: tạo temp keychain cho CI
  end

  lane :beta do
    match(type: "appstore", readonly: true)
    increment_build_number(build_number: ENV["GITHUB_RUN_NUMBER"])
    build_app(scheme: "MyApp", export_method: "app-store")
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end

  lane :release do
    match(type: "appstore", readonly: true)
    build_app(scheme: "MyApp", export_method: "app-store")
    upload_to_app_store(
      submit_for_review: true,
      automatic_release: false,
      precheck_include_in_app_purchases: false
    )
  end
end
```

---

## 5. Cách Setup Secrets

Đây là phần hay gây nhầm lẫn nhất. Cần lưu certificate và profile dưới dạng base64 trong GitHub Secrets:

```bash
# Encode certificate (.p12) → paste vào secret APPLE_CERTIFICATE_P12
base64 -i Certificates.p12 | pbcopy

# Encode provisioning profile → paste vào secret PROVISIONING_PROFILE
base64 -i MyApp_Distribution.mobileprovision | pbcopy

# App Store Connect API Key → tạo tại https://appstoreconnect.apple.com/access/api
# Cần 3 secrets:
#   ASC_KEY_ID       → Key ID (vd: ABC123XYZ)
#   ASC_ISSUER_ID    → Issuer ID (UUID)
#   ASC_PRIVATE_KEY  → Nội dung file .p8
```

Danh sách secrets cần thiết:

| Secret | Mô tả |
|---|---|
| `APPLE_CERTIFICATE_P12` | Distribution cert, base64 encoded |
| `APPLE_CERTIFICATE_PASSWORD` | Password của file .p12 |
| `PROVISIONING_PROFILE` | .mobileprovision, base64 encoded |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `ASC_PRIVATE_KEY` | Nội dung file .p8 |
| `SLACK_WEBHOOK` | Slack incoming webhook URL |

---

## 6. Composite Action — Tái sử dụng setup chung

```yaml
# .github/actions/setup-ios/action.yml
name: 'Setup iOS Build Environment'
description: 'Cài đặt Xcode, cache SPM, setup keychain'

inputs:
  xcode-version:
    description: 'Xcode version'
    required: false
    default: '16.0'
  certificate-p12:
    description: 'Base64 encoded .p12'
    required: false
  certificate-password:
    description: 'P12 password'
    required: false

runs:
  using: composite
  steps:
    - name: Select Xcode
      shell: bash
      run: sudo xcode-select -s /Applications/Xcode_${{ inputs.xcode-version }}.app

    - name: Cache SPM
      uses: actions/cache@v4
      with:
        path: |
          build/DerivedData/SourcePackages
          ~/Library/Caches/org.swift.swiftpm
        key: spm-${{ runner.os }}-${{ hashFiles('**/Package.resolved') }}
        restore-keys: spm-${{ runner.os }}-

    - name: Setup Keychain
      if: inputs.certificate-p12 != ''
      shell: bash
      run: |
        # ... (code setup keychain như trên)
```

Sau đó dùng trong workflow:
```yaml
- uses: ./.github/actions/setup-ios
  with:
    xcode-version: '16.0'
    certificate-p12: ${{ secrets.APPLE_CERTIFICATE_P12 }}
    certificate-password: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
```

---

## 7. Tips Production-Grade

**Tối ưu thời gian chạy:**
- Cache SPM/CocoaPods giúp giảm 2-5 phút mỗi run
- Dùng `build-for-testing` + `test-without-building` để parallel test trên nhiều simulator (matrix strategy)
- `concurrency` + `cancel-in-progress` tránh chạy run thừa

**Bảo mật:**
- Luôn cleanup keychain trong `if: always()` block
- Dùng **App Store Connect API Key** thay vì Apple ID + App-specific password (API Key an toàn hơn và không bị 2FA)
- Nếu dùng Fastlane Match, đặt `readonly: true` trong CI để không bao giờ tạo cert mới từ CI

**Monitoring:**
- Upload `.xcresult` bundle làm artifact để debug test failure
- Dùng `xcbeautify --renderer github-actions` để hiện error/warning ngay trên PR
- Set `timeout-minutes` hợp lý (30 phút cho CI, 45 phút cho release)

**Branching strategy phổ biến:**
- PR → `develop`: Chạy CI (build + test + lint)
- Merge vào `main`: Chạy CI + deploy TestFlight
- Push tag `v*`: Build release + upload App Store Connect

Nếu cần mình đi sâu hơn vào phần nào (ví dụ matrix testing, self-hosted runner, hoặc Tuist + GitHub Actions), cứ hỏi nhé!
