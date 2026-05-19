# CI/CD Integration cho iOS Testing — Senior Developer Guide

CI/CD cho iOS testing là khả năng tự động hoá việc build, test, và delivery app mỗi khi code thay đổi. Senior dev không chỉ viết test mà phải **thiết kế và maintain cả pipeline** đảm bảo test chạy tự động, nhanh, và đáng tin cậy.

---

## 1. Hiểu bức tranh tổng thể

```
Developer push code
        │
        ▼
┌──────────────────┐
│   CI Triggered    │  ← GitHub Actions / Bitrise / Jenkins
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│   Build App       │  ← xcodebuild build / fastlane build
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│   Unit Tests      │  ← Nhanh, chạy trước
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│   UI Tests        │  ← Chậm hơn, chạy sau
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  Code Coverage    │  ← Report + enforce threshold
│  Static Analysis  │  ← SwiftLint, periphery
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  Report Results   │  ← PR status check, Slack notification
└──────┬───────────┘
       │
       ▼
  ✅ Merge / ❌ Block
```

---

## 2. xcodebuild test — Công cụ gốc từ Apple

### Lệnh cơ bản

```bash
xcodebuild test \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  -resultBundlePath ./TestResults.xcresult
```

Phân tích từng parameter:

- **`-workspace`** hoặc **`-project`** — trỏ đến workspace (nếu dùng CocoaPods/SPM) hoặc project file
- **`-scheme`** — scheme chứa test targets. Senior dev thường tạo scheme riêng cho test, ví dụ `MyApp-UnitTests`, `MyApp-UITests`
- **`-destination`** — chỉ định simulator. Trên CI thường dùng generic destination hoặc chỉ định cụ thể
- **`-resultBundlePath`** — output `.xcresult` bundle chứa logs, screenshots, coverage

### Các options quan trọng cho CI

```bash
xcodebuild test \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  -resultBundlePath ./TestResults.xcresult \
  -enableCodeCoverage YES \                    # Bật code coverage
  -only-testing:MyAppTests/LoginTests \        # Chỉ chạy test cụ thể
  -skip-testing:MyAppUITests/SlowFlowTests \   # Bỏ qua test cụ thể
  -retry-tests-on-failure \                    # Retry test fail (Xcode 13+)
  -test-iterations 2 \                         # Số lần retry
  -parallel-testing-enabled YES \              # Chạy song song
  -maximum-concurrent-test-simulator-destinations 3 \  # Tối đa 3 simulator
  -test-timeouts-enabled YES \                 # Timeout cho từng test
  -default-test-execution-time-allowance 300   # 5 phút mỗi test
```

### Tách Unit Test và UI Test thành 2 jobs riêng

Đây là pattern quan trọng mà senior dev áp dụng. Unit test nhanh nên chạy trước, UI test chậm chạy sau (hoặc parallel):

```bash
# Job 1: Unit Tests — chạy nhanh, block PR sớm nếu fail
xcodebuild test \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  -only-testing:MyAppTests \
  -enableCodeCoverage YES \
  -resultBundlePath ./UnitTestResults.xcresult

# Job 2: UI Tests — chạy parallel, có retry
xcodebuild test \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  -only-testing:MyAppUITests \
  -parallel-testing-enabled YES \
  -retry-tests-on-failure \
  -test-iterations 2 \
  -resultBundlePath ./UITestResults.xcresult
```

### Xử lý output — xcresult bundle

`.xcresult` chứa mọi thứ: test results, logs, screenshots, code coverage. Senior dev cần biết extract thông tin từ đây:

```bash
# Xem summary
xcrun xcresulttool get --path TestResults.xcresult --format json

# Export code coverage report
xcrun xccov view --report --json TestResults.xcresult > coverage.json

# Export sang format khác (Cobertura cho CI tools)
# Dùng tool như xcresultparser hoặc slather
xcresultparser -o cobertura TestResults.xcresult > coverage.xml
```

### Derived Data & Caching

Build trên CI rất chậm nếu mỗi lần build từ đầu. Senior dev cấu hình cache:

```bash
# Chỉ định derived data path để cache
xcodebuild test \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  -derivedDataPath ./DerivedData \
  -resultBundlePath ./TestResults.xcresult

# Trong CI, cache thư mục DerivedData giữa các runs
# Và cache SPM:
# ~/Library/Developer/Xcode/DerivedData/
# ~/Library/Caches/org.swift.swiftpm/
```

---

## 3. Fastlane — Abstraction Layer trên xcodebuild

### Tại sao dùng Fastlane?

`xcodebuild` mạnh nhưng verbose và khó maintain. Fastlane wrap lại thành DSL dễ đọc, thêm nhiều tính năng: auto-retry, report formatting, Slack notification, code signing...

### Cài đặt

```ruby
# Gemfile
source "https://rubygems.org"

gem "fastlane", "~> 2.220"
gem "xcpretty", "~> 0.3"  # Format xcodebuild output đẹp hơn

# Install
bundle install
```

### Fastfile cơ bản

```ruby
# fastlane/Fastfile

default_platform(:ios)

platform :ios do

  # ─── UNIT TESTS ─────────────────────────────
  desc "Run unit tests"
  lane :unit_tests do
    scan(
      workspace: "MyApp.xcworkspace",
      scheme: "MyApp",
      devices: ["iPhone 16"],
      only_testing: ["MyAppTests"],
      code_coverage: true,
      output_directory: "./test_reports",
      output_types: "html,junit",      # Xuất cả HTML report và JUnit XML
      result_bundle: true,
      clean: false,                     # Không clean build — dùng cache
      xcargs: "-skipPackagePluginValidation"
    )
  end

  # ─── UI TESTS ───────────────────────────────
  desc "Run UI tests"
  lane :ui_tests do
    scan(
      workspace: "MyApp.xcworkspace",
      scheme: "MyApp",
      devices: ["iPhone 16"],
      only_testing: ["MyAppUITests"],
      result_bundle: true,
      output_directory: "./test_reports",
      output_types: "html,junit",
      number_of_retries: 2,            # Retry mỗi failed test 2 lần
      concurrent_workers: 3             # 3 simulators song song
    )
  end

  # ─── ALL TESTS ──────────────────────────────
  desc "Run all tests"
  lane :test do
    unit_tests
    ui_tests
  end

  # ─── COVERAGE CHECK ─────────────────────────
  desc "Check code coverage meets threshold"
  lane :check_coverage do
    unit_tests

    # Parse coverage từ xcresult
    coverage = sh(
      "xcrun xccov view --report --json " \
      "./test_reports/MyApp.xcresult | " \
      "python3 -c \"import sys,json; " \
      "print(json.load(sys.stdin)['lineCoverage'])\""
    ).strip.to_f

    min_coverage = 0.70  # 70%

    if coverage < min_coverage
      UI.user_error!(
        "Code coverage #{(coverage * 100).round(1)}% " \
        "is below minimum #{(min_coverage * 100).round(1)}%"
      )
    else
      UI.success(
        "Code coverage: #{(coverage * 100).round(1)}% ✓"
      )
    end
  end
end
```

### Chạy Fastlane

```bash
# Chạy unit tests
bundle exec fastlane unit_tests

# Chạy UI tests
bundle exec fastlane ui_tests

# Chạy tất cả
bundle exec fastlane test

# Check coverage
bundle exec fastlane check_coverage
```

### Fastlane scan — Chi tiết các options quan trọng

```ruby
scan(
  # ─── Project settings ────────────────────
  workspace: "MyApp.xcworkspace",
  scheme: "MyApp",
  configuration: "Debug",           # Build config cho test
  
  # ─── Destination ─────────────────────────
  devices: ["iPhone 16", "iPad Pro (13-inch)"],  # Multi-device
  # Hoặc:
  # destination: "platform=iOS Simulator,name=iPhone 16,OS=18.0",
  
  # ─── Test filtering ─────────────────────
  only_testing: [
    "MyAppTests/LoginTests",
    "MyAppTests/CartTests"
  ],
  skip_testing: [
    "MyAppTests/DeprecatedTests"
  ],
  
  # ─── Execution ───────────────────────────
  clean: false,                      # Tận dụng incremental build
  number_of_retries: 2,              # Retry failed tests
  concurrent_workers: 4,             # Parallel simulators
  max_concurrent_simulators: 4,
  disable_concurrent_testing: false,
  
  # ─── Coverage ────────────────────────────
  code_coverage: true,
  
  # ─── Output ──────────────────────────────
  output_directory: "./test_reports",
  output_types: "html,junit",        # junit cho CI parsing
  output_files: "unit_tests.html,unit_tests.xml",
  result_bundle: true,               # Full .xcresult bundle
  buildlog_path: "./build_logs",
  
  # ─── Behavior ────────────────────────────
  fail_build: true,                  # CI fail nếu test fail
  
  # ─── Extra args ──────────────────────────
  xcargs: "-skipPackagePluginValidation -test-timeouts-enabled YES"
)
```

---

## 4. GitHub Actions — Full Pipeline Setup

### Workflow cho Pull Request

```yaml
# .github/workflows/tests.yml
name: iOS Tests

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

# Cancel runs cũ khi có push mới vào cùng PR
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  DEVELOPER_DIR: /Applications/Xcode_16.0.app/Contents/Developer
  SCHEME: MyApp
  WORKSPACE: MyApp.xcworkspace

jobs:
  # ═══════════════════════════════════════════════
  # Job 1: Unit Tests — chạy nhanh, block sớm
  # ═══════════════════════════════════════════════
  unit-tests:
    name: Unit Tests
    runs-on: macos-15            # macOS Sequoia runner
    timeout-minutes: 20

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # Cache SPM dependencies
      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: |
            ~/Library/Caches/org.swift.swiftpm
            ~/Library/Developer/Xcode/DerivedData
          key: spm-${{ hashFiles('**/Package.resolved') }}
          restore-keys: spm-

      # Resolve dependencies trước (tách riêng để debug dễ)
      - name: Resolve Dependencies
        run: |
          xcodebuild -resolvePackageDependencies \
            -workspace $WORKSPACE \
            -scheme $SCHEME \
            -clonedSourcePackagesDirPath ./SPMCache

      # Chạy unit tests
      - name: Run Unit Tests
        run: |
          set -o pipefail
          xcodebuild test \
            -workspace $WORKSPACE \
            -scheme $SCHEME \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
            -only-testing:MyAppTests \
            -enableCodeCoverage YES \
            -derivedDataPath ./DerivedData \
            -clonedSourcePackagesDirPath ./SPMCache \
            -resultBundlePath ./UnitTestResults.xcresult \
            | xcbeautify  # Format output đẹp

      # Extract và check coverage
      - name: Check Code Coverage
        run: |
          COVERAGE=$(xcrun xccov view --report --json \
            ./UnitTestResults.xcresult | \
            python3 -c "import sys,json; \
            print(round(json.load(sys.stdin)['lineCoverage'] * 100, 1))")
          echo "Coverage: ${COVERAGE}%"
          echo "coverage=${COVERAGE}" >> $GITHUB_OUTPUT
          
          # Fail nếu coverage < 70%
          python3 -c "
          coverage = float('${COVERAGE}')
          if coverage < 70.0:
              print(f'Coverage {coverage}% is below 70% threshold')
              exit(1)
          print(f'Coverage {coverage}% meets threshold')
          "
        id: coverage

      # Upload results nếu fail
      - name: Upload Test Results
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: unit-test-results
          path: ./UnitTestResults.xcresult
          retention-days: 7

      # Comment coverage lên PR
      - name: Comment Coverage on PR
        if: github.event_name == 'pull_request'
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          header: coverage
          message: |
            ### Test Coverage Report
            **Coverage: ${{ steps.coverage.outputs.coverage }}%**
            Minimum threshold: 70%

  # ═══════════════════════════════════════════════
  # Job 2: UI Tests — chạy parallel với unit tests
  # ═══════════════════════════════════════════════
  ui-tests:
    name: UI Tests
    runs-on: macos-15
    timeout-minutes: 40

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: |
            ~/Library/Caches/org.swift.swiftpm
          key: spm-${{ hashFiles('**/Package.resolved') }}
          restore-keys: spm-

      - name: Run UI Tests
        run: |
          set -o pipefail
          xcodebuild test \
            -workspace $WORKSPACE \
            -scheme $SCHEME \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
            -only-testing:MyAppUITests \
            -parallel-testing-enabled YES \
            -retry-tests-on-failure \
            -test-iterations 2 \
            -derivedDataPath ./DerivedData \
            -resultBundlePath ./UITestResults.xcresult \
            | xcbeautify

      # Upload screenshots khi fail — cực kỳ quan trọng để debug
      - name: Upload UI Test Results
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: ui-test-results
          path: ./UITestResults.xcresult
          retention-days: 7

  # ═══════════════════════════════════════════════
  # Job 3: Static Analysis
  # ═══════════════════════════════════════════════
  lint:
    name: Lint & Static Analysis
    runs-on: macos-15
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4

      - name: SwiftLint
        run: |
          if command -v swiftlint &> /dev/null; then
            swiftlint lint --reporter github-actions-logging
          else
            brew install swiftlint
            swiftlint lint --reporter github-actions-logging
          fi
```

### Giải thích các quyết định kiến trúc

**Tại sao tách 3 jobs riêng biệt?** — Unit tests, UI tests, và lint chạy **parallel** trên 3 runners khác nhau. Nếu gộp chung sequential, pipeline tổng mất ~60 phút. Tách ra chỉ mất ~40 phút (bằng job chậm nhất). Thêm nữa, developer nhận feedback lint trong 10 phút thay vì chờ 60 phút.

**`cancel-in-progress: true`** — khi developer push commit mới vào PR, CI run cũ bị cancel ngay. Tiết kiệm runner minutes đáng kể.

**`set -o pipefail`** — mặc định pipe trong bash chỉ check exit code của command cuối (`xcbeautify`). Không có `pipefail`, nếu `xcodebuild` fail nhưng `xcbeautify` thành công thì CI vẫn xanh — bug rất nguy hiểm.

**`timeout-minutes`** — prevent hung builds chiếm runner vô thời hạn. Unit tests 20 phút là quá đủ, UI tests cho 40 phút.

---

## 5. Bitrise — iOS-focused CI

Bitrise được thiết kế chuyên cho mobile, có sẵn macOS runners với Xcode cài đặt đầy đủ.

### bitrise.yml

```yaml
# bitrise.yml
format_version: "13"

pipelines:
  pr-checks:
    stages:
      - test-stage: {}

stages:
  test-stage:
    workflows:
      - unit-tests: {}
      - ui-tests: {}     # Chạy parallel

workflows:
  unit-tests:
    steps:
      - git-clone@8: {}
      
      - cache-pull@2: {}
      
      - xcode-test@5:
          inputs:
            - project_path: MyApp.xcworkspace
            - scheme: MyApp
            - destination: "platform=iOS Simulator,name=iPhone 16,OS=18.0"
            - test_plan: UnitTests
            - generate_code_coverage_files: "yes"
            - xcpretty_test_options: "--report junit --output $BITRISE_TEST_RESULT_DIR/junit.xml"
      
      - cache-push@2:
          inputs:
            - cache_paths: |
                ~/Library/Caches/org.swift.swiftpm
                ./DerivedData
      
      - deploy-to-bitrise-io@2:
          inputs:
            - is_enable_public_page: "false"

  ui-tests:
    steps:
      - git-clone@8: {}
      
      - cache-pull@2: {}
      
      - xcode-test@5:
          inputs:
            - project_path: MyApp.xcworkspace
            - scheme: MyApp
            - destination: "platform=iOS Simulator,name=iPhone 16,OS=18.0"
            - test_plan: UITests
            - test_repetition_mode: retry_on_failure
            - maximum_test_repetitions: 2
      
      - deploy-to-bitrise-io@2: {}
```

---

## 6. Fastlane + CI kết hợp — Best Practice

Nhiều team dùng Fastlane bên trong CI. Ưu điểm lớn: **developer chạy cùng lệnh trên local và CI**, tránh "works on my machine".

```yaml
# .github/workflows/tests.yml — phiên bản Fastlane
name: iOS Tests

on:
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: macos-15
    timeout-minutes: 30

    steps:
      - uses: actions/checkout@v4

      - name: Cache Ruby gems
        uses: actions/cache@v4
        with:
          path: vendor/bundle
          key: gems-${{ hashFiles('Gemfile.lock') }}

      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: ~/Library/Caches/org.swift.swiftpm
          key: spm-${{ hashFiles('**/Package.resolved') }}

      - name: Install Dependencies
        run: bundle install --path vendor/bundle

      - name: Run Unit Tests
        run: bundle exec fastlane unit_tests

      - name: Run UI Tests
        run: bundle exec fastlane ui_tests

      - name: Upload Results
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-reports
          path: ./test_reports/
```

Developer trên local cũng chạy cùng lệnh:

```bash
# Local — cùng lệnh y hệt CI
bundle exec fastlane unit_tests
bundle exec fastlane ui_tests
```

---

## 7. Xcode Test Plans — Quản lý test configurations

Senior dev dùng Test Plans (`.xctestplan`) để quản lý nhiều test configurations. Đây là file JSON mà Xcode generate, cho phép bạn define test nào chạy, environment variables, arguments, language, region...

```json
{
  "configurations": [
    {
      "name": "Default",
      "options": {
        "language": "en",
        "region": "US",
        "environmentVariableEntries": [
          { "key": "MOCK_API", "value": "true" }
        ],
        "codeCoverage": true,
        "testRepetitionMode": "retryOnFailure",
        "maximumTestRepetitions": 2
      }
    },
    {
      "name": "Japanese Localization",
      "options": {
        "language": "ja",
        "region": "JP"
      }
    }
  ],
  "testTargets": [
    {
      "target": { "name": "MyAppTests" },
      "enabled": true
    },
    {
      "target": { "name": "MyAppUITests" },
      "enabled": true,
      "skippedTests": [
        "SlowPerformanceTests"
      ]
    }
  ]
}
```

Sử dụng trong xcodebuild:

```bash
xcodebuild test \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -testPlan UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0'
```

Trong fastlane:

```ruby
scan(
  workspace: "MyApp.xcworkspace",
  scheme: "MyApp",
  testplan: "UnitTests"
)
```

---

## 8. Tối ưu CI Performance — Senior-level Concerns

### Build Time Optimization

```bash
# 1. Incremental builds — KHÔNG clean mỗi lần
xcodebuild test -derivedDataPath ./DerivedData  # Cache DerivedData

# 2. Chỉ build test target cần thiết
xcodebuild build-for-testing \     # Tách build và test
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -derivedDataPath ./DerivedData

xcodebuild test-without-building \ # Test dùng build đã có
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -derivedDataPath ./DerivedData \
  -only-testing:MyAppTests
```

**`build-for-testing` + `test-without-building`** là pattern cực kỳ mạnh. Build 1 lần, rồi chạy test nhiều lần (trên nhiều destinations, nhiều configurations) mà không cần build lại.

```yaml
# Build 1 lần, test trên nhiều devices
jobs:
  build:
    runs-on: macos-15
    steps:
      - run: |
          xcodebuild build-for-testing \
            -workspace MyApp.xcworkspace \
            -scheme MyApp \
            -derivedDataPath ./DerivedData
      - uses: actions/upload-artifact@v4
        with:
          name: derived-data
          path: ./DerivedData

  test-iphone:
    needs: build
    runs-on: macos-15
    steps:
      - uses: actions/download-artifact@v4
        with: { name: derived-data, path: ./DerivedData }
      - run: |
          xcodebuild test-without-building \
            -derivedDataPath ./DerivedData \
            -destination 'name=iPhone 16'

  test-ipad:
    needs: build
    runs-on: macos-15
    steps:
      - uses: actions/download-artifact@v4
        with: { name: derived-data, path: ./DerivedData }
      - run: |
          xcodebuild test-without-building \
            -derivedDataPath ./DerivedData \
            -destination 'name=iPad Pro (13-inch)'
```

### Selective Testing — Chỉ test module bị ảnh hưởng

Với project lớn modularize bằng SPM, senior dev có thể build script detect module nào thay đổi và chỉ test module đó:

```bash
#!/bin/bash
# detect_changed_modules.sh

CHANGED_FILES=$(git diff --name-only origin/main...HEAD)

MODULES_TO_TEST=""

if echo "$CHANGED_FILES" | grep -q "Sources/Networking/"; then
  MODULES_TO_TEST="$MODULES_TO_TEST NetworkingTests"
fi

if echo "$CHANGED_FILES" | grep -q "Sources/Cart/"; then
  MODULES_TO_TEST="$MODULES_TO_TEST CartTests"
fi

if echo "$CHANGED_FILES" | grep -q "Sources/Auth/"; then
  MODULES_TO_TEST="$MODULES_TO_TEST AuthTests"
fi

# Nếu core modules thay đổi -> test tất cả
if echo "$CHANGED_FILES" | grep -q "Sources/Core/"; then
  MODULES_TO_TEST="ALL"
fi

echo "modules=$MODULES_TO_TEST" >> $GITHUB_OUTPUT
```

---

## 9. Monitoring & Notifications

### Slack Notification khi CI fail

```ruby
# Fastfile
lane :test do
  begin
    scan(
      workspace: "MyApp.xcworkspace",
      scheme: "MyApp",
      result_bundle: true
    )
  rescue => error
    slack(
      message: "❌ Tests failed on #{git_branch}",
      slack_url: ENV["SLACK_WEBHOOK_URL"],
      payload: {
        "Build" => ENV["CI_BUILD_NUMBER"],
        "Error" => error.message
      },
      default_payloads: [:git_branch, :last_git_commit]
    )
    raise error  # Re-raise để CI vẫn fail
  end
  
  # Success notification
  slack(
    message: "✅ All tests passed on #{git_branch}",
    slack_url: ENV["SLACK_WEBHOOK_URL"],
    success: true,
    default_payloads: [:git_branch, :last_git_commit]
  )
end
```

---

## 10. Tư duy Senior về CI/CD Testing

Một số nguyên tắc quan trọng:

**Pipeline phải nhanh** — nếu developer phải chờ 45+ phút để biết PR pass hay fail, họ sẽ context-switch, mất productivity. Target: unit tests < 10 phút, toàn bộ pipeline < 25 phút. Nếu vượt quá, cần optimize (parallel, selective testing, caching, `build-for-testing`).

**Reproducible** — local chạy được thì CI cũng chạy được và ngược lại. Fastlane giúp đảm bảo điều này. Tránh CI-specific hacks mà developer không reproduce được.

**Test results phải actionable** — khi test fail trên CI, developer phải biết ngay: test nào fail, screenshot (cho UI test), log rõ ràng. Upload `.xcresult` bundle là bắt buộc.

**Không bao giờ ignore test failure** — nếu team quen với "test đỏ bình thường" thì test suite mất giá trị. Senior dev enforce: red build = blocked merge, không có ngoại lệ. Flaky tests phải được quarantine hoặc fix ngay, không để nằm trong main suite.
