![pr_develop_to_main_flow](https://github.com/user-attachments/assets/ebc97b3d-3ac2-4bf3-bee1-6a767de611fd)## PR Workflow: `develop` → `main`

Đây là pipeline thực tế khi tạo PR merge từ `develop` lên `main`, thường đại diện cho một **release candidate** — nên cần kiểm tra kỹ hơn PR thông thường.

```
# .github/workflows/pr-develop-main.yml
# ═══════════════════════════════════════════════════════
# Workflow: PR từ develop → main (Release Candidate)
# ═══════════════════════════════════════════════════════
name: "🚀 Release PR: develop → main"

on:
  pull_request:
    branches: [main]
    # Chỉ trigger khi source branch là develop
    types: [opened, synchronize, reopened, ready_for_review]

concurrency:
  group: release-pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

env:
  SCHEME: "MyApp"
  PROJECT: "MyApp.xcodeproj"
  DESTINATION: "platform=iOS Simulator,name=iPhone 16,OS=18.0"
  XCODE_VERSION: "16.0"
  DERIVED_DATA: "build/DerivedData"
  MINIMUM_COVERAGE: 80

# ─────────────────────────────────────────────────────────
# STEP 1: PARALLEL QUALITY GATES
# Chạy đồng thời: Lint, Build+Test, Security
# ─────────────────────────────────────────────────────────
jobs:

  # ═══ 1A: LINT + STATIC ANALYSIS ═══════════════════════
  lint:
    name: "🧹 Lint + Static Analysis"
    runs-on: macos-15
    timeout-minutes: 10
    # Skip draft PRs
    if: github.event.pull_request.draft == false

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app

      # ── SwiftLint ──
      - name: SwiftLint
        run: |
          brew install swiftlint
          # Chỉ lint các file thay đổi trong PR (nhanh hơn lint toàn bộ)
          git diff --name-only --diff-filter=ACMR \
            origin/${{ github.base_ref }}...HEAD -- '*.swift' \
            | xargs -I{} swiftlint lint --strict \
              --reporter github-actions-logging \
              --path "{}" || true
          
          # Vẫn lint toàn bộ project để catch error
          swiftlint lint --strict --reporter github-actions-logging

      # ── SwiftFormat check ──
      - name: SwiftFormat (check only)
        run: |
          brew install swiftformat
          swiftformat --lint . 2>&1 | while read line; do
            echo "::warning::$line"
          done
          # Strict mode: fail nếu format sai
          swiftformat --lint .

      # ── Periphery: detect dead code ──
      - name: Dead Code Detection
        continue-on-error: true  # Warn but don't block
        run: |
          brew install peripheryapp/periphery/periphery
          periphery scan \
            --project "${{ env.PROJECT }}" \
            --schemes "${{ env.SCHEME }}" \
            --targets "${{ env.SCHEME }}" \
            --format github-actions \
            --index-exclude ".*Tests.*" ".*Mock.*"


  # ═══ 1B: BUILD + UNIT TEST ════════════════════════════
  build-and-test:
    name: "🔨 Build + Unit Test"
    runs-on: macos-15
    timeout-minutes: 30
    if: github.event.pull_request.draft == false

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app

      # ── Cache SPM ──
      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: |
            ${{ env.DERIVED_DATA }}/SourcePackages
            ~/Library/Caches/org.swift.swiftpm
          key: spm-${{ runner.os }}-${{ hashFiles('**/Package.resolved') }}
          restore-keys: spm-${{ runner.os }}-

      # ── Build ──
      - name: Build for Testing
        run: |
          set -o pipefail
          xcodebuild build-for-testing \
            -project "${{ env.PROJECT }}" \
            -scheme "${{ env.SCHEME }}" \
            -destination "${{ env.DESTINATION }}" \
            -derivedDataPath "${{ env.DERIVED_DATA }}" \
            -enableCodeCoverage YES \
            CODE_SIGNING_ALLOWED=NO \
            COMPILER_INDEX_STORE_ENABLE=NO \
            | xcbeautify --renderer github-actions

      # ── Unit Tests ──
      - name: Run Unit Tests
        run: |
          set -o pipefail
          xcodebuild test-without-building \
            -project "${{ env.PROJECT }}" \
            -scheme "${{ env.SCHEME }}" \
            -destination "${{ env.DESTINATION }}" \
            -derivedDataPath "${{ env.DERIVED_DATA }}" \
            -enableCodeCoverage YES \
            -resultBundlePath "build/UnitTest.xcresult" \
            -only-testing:"MyAppTests" \
            | xcbeautify --renderer github-actions

      # ── Coverage Report ──
      - name: Extract Coverage
        id: coverage
        if: always()
        run: |
          xcrun xccov view --report --json \
            "build/UnitTest.xcresult" > build/coverage.json
          
          COVERAGE=$(python3 << 'EOF'
          import json
          with open("build/coverage.json") as f:
              data = json.load(f)
          cov = data["lineCoverage"] * 100
          print(f"{cov:.1f}")
          EOF
          )
          echo "value=$COVERAGE" >> $GITHUB_OUTPUT
          echo "📊 Coverage: ${COVERAGE}%"

      # ── Upload artifacts for later jobs ──
      - name: Upload DerivedData (for UI test job)
        uses: actions/upload-artifact@v4
        with:
          name: derived-data
          path: ${{ env.DERIVED_DATA }}
          retention-days: 1

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: unit-test-results
          path: build/UnitTest.xcresult
          retention-days: 7

    outputs:
      coverage: ${{ steps.coverage.outputs.value }}


  # ═══ 1C: SECURITY SCAN ════════════════════════════════
  security:
    name: "🔒 Security Scan"
    runs-on: macos-15
    timeout-minutes: 10
    if: github.event.pull_request.draft == false

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history cho secret scan

      # ── Dependency vulnerability check ──
      - name: Check SPM Dependencies
        run: |
          # Kiểm tra Package.resolved có dependency nào
          # nằm trong known vulnerability list không
          swift package audit 2>&1 || true

      # ── Secret leak detection ──
      - name: Secret Scanning
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.pull_request.base.sha }}
          head: ${{ github.event.pull_request.head.sha }}
          extra_args: --only-verified

      # ── Check for hardcoded credentials ──
      - name: Grep for Potential Secrets
        run: |
          # Tìm patterns nghi ngờ trong code mới
          PATTERNS="password|secret|api_key|private_key|bearer|token"
          FILES=$(git diff --name-only --diff-filter=ACMR \
            origin/${{ github.base_ref }}...HEAD -- '*.swift')
          
          if [ -n "$FILES" ]; then
            echo "$FILES" | xargs grep -inE "$PATTERNS" \
              --include="*.swift" || echo "✅ No suspicious patterns"
          fi


  # ─────────────────────────────────────────────────────────
  # STEP 2: COVERAGE GATE
  # Chạy sau build-and-test, enforce minimum coverage
  # ─────────────────────────────────────────────────────────
  coverage-gate:
    name: "📊 Coverage Gate (≥${{ env.MINIMUM_COVERAGE }}%)"
    runs-on: ubuntu-latest
    timeout-minutes: 5
    needs: [build-and-test]

    steps:
      - name: Check Coverage Threshold
        env:
          COVERAGE: ${{ needs.build-and-test.outputs.coverage }}
        run: |
          echo "📊 Current coverage: ${COVERAGE}%"
          echo "📏 Minimum required: ${{ env.MINIMUM_COVERAGE }}%"
          
          if (( $(echo "$COVERAGE < ${{ env.MINIMUM_COVERAGE }}" | bc -l) )); then
            echo "::error::❌ Coverage ${COVERAGE}% is below minimum ${{ env.MINIMUM_COVERAGE }}%"
            echo ""
            echo "💡 Tips:"
            echo "  - Thêm unit test cho code mới"
            echo "  - Kiểm tra file nào chưa được cover: xccov view --files-for-target"
            exit 1
          fi
          
          echo "✅ Coverage ${COVERAGE}% meets threshold"


  # ─────────────────────────────────────────────────────────
  # STEP 3: UI TESTS
  # Chạy sau build thành công (dùng lại DerivedData)
  # ─────────────────────────────────────────────────────────
  ui-tests:
    name: "📱 UI Tests"
    runs-on: macos-15
    timeout-minutes: 30
    needs: [build-and-test]

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app

      # ── Download build artifacts ──
      - name: Download DerivedData
        uses: actions/download-artifact@v4
        with:
          name: derived-data
          path: ${{ env.DERIVED_DATA }}

      # ── Boot Simulator ──
      - name: Boot Simulator
        run: |
          DEVICE_ID=$(xcrun simctl list devices available -j \
            | python3 -c "
          import json, sys
          data = json.load(sys.stdin)
          for runtime, devices in data['devices'].items():
              if '18.0' in runtime:
                  for d in devices:
                      if d['name'] == 'iPhone 16':
                          print(d['udid']); sys.exit(0)
          ")
          xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
          echo "DEVICE_UDID=$DEVICE_ID" >> $GITHUB_ENV

      # ── Run UI Tests ──
      - name: Run UI Tests
        run: |
          set -o pipefail
          xcodebuild test-without-building \
            -project "${{ env.PROJECT }}" \
            -scheme "${{ env.SCHEME }}" \
            -destination "id=${{ env.DEVICE_UDID }}" \
            -derivedDataPath "${{ env.DERIVED_DATA }}" \
            -resultBundlePath "build/UITest.xcresult" \
            -only-testing:"MyAppUITests" \
            | xcbeautify --renderer github-actions

      # ── Snapshot Tests (nếu dùng) ──
      # - name: Snapshot Tests
      #   run: |
      #     xcodebuild test-without-building \
      #       -project "${{ env.PROJECT }}" \
      #       -scheme "SnapshotTests" \
      #       ...

      - name: Upload UI Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: ui-test-results
          path: build/UITest.xcresult
          retention-days: 7


  # ─────────────────────────────────────────────────────────
  # STEP 4: ARCHIVE + EXPORT IPA
  # Chạy sau TẤT CẢ quality gates pass
  # ─────────────────────────────────────────────────────────
  archive:
    name: "📦 Archive + Export IPA"
    runs-on: macos-15
    timeout-minutes: 30
    needs: [lint, build-and-test, security, coverage-gate, ui-tests]

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app

      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: |
            ${{ env.DERIVED_DATA }}/SourcePackages
            ~/Library/Caches/org.swift.swiftpm
          key: spm-${{ runner.os }}-${{ hashFiles('**/Package.resolved') }}

      # ── Code Signing Setup ──
      - name: Setup Code Signing
        env:
          P12_BASE64: ${{ secrets.APPLE_CERTIFICATE_P12 }}
          P12_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
          PROFILE_BASE64: ${{ secrets.PROVISIONING_PROFILE }}
        run: |
          KEYCHAIN="build.keychain"
          KEYCHAIN_PASS="ci_temp_pass"
          
          security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
          security set-keychain-settings -lut 21600 "$KEYCHAIN"
          security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
          
          echo "$P12_BASE64" | base64 --decode > /tmp/cert.p12
          security import /tmp/cert.p12 -k "$KEYCHAIN" \
            -P "$P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
          security set-key-partition-list -S apple-tool:,apple: \
            -s -k "$KEYCHAIN_PASS" "$KEYCHAIN"
          security list-keychains -d user -s "$KEYCHAIN" login.keychain-db
          
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          echo "$PROFILE_BASE64" | base64 --decode \
            > ~/Library/MobileDevice/Provisioning\ Profiles/build.mobileprovision
          
          rm /tmp/cert.p12

      # ── Determine Version ──
      - name: Set Build Version
        run: |
          # Version từ Info.plist hoặc project settings
          VERSION=$(xcodebuild -project "${{ env.PROJECT }}" \
            -scheme "${{ env.SCHEME }}" \
            -showBuildSettings 2>/dev/null \
            | grep MARKETING_VERSION \
            | head -1 | awk '{print $3}')
          BUILD=${{ github.run_number }}
          
          echo "VERSION=$VERSION" >> $GITHUB_ENV
          echo "BUILD_NUMBER=$BUILD" >> $GITHUB_ENV
          echo "📦 Building v${VERSION} (${BUILD})"

      # ── Archive ──
      - name: Archive
        run: |
          set -o pipefail
          xcodebuild archive \
            -project "${{ env.PROJECT }}" \
            -scheme "${{ env.SCHEME }}" \
            -configuration Release \
            -destination "generic/platform=iOS" \
            -archivePath "build/MyApp.xcarchive" \
            -derivedDataPath "${{ env.DERIVED_DATA }}" \
            MARKETING_VERSION="${{ env.VERSION }}" \
            CURRENT_PROJECT_VERSION="${{ env.BUILD_NUMBER }}" \
            | xcbeautify

      # ── Export IPA ──
      - name: Export IPA
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
          </dict>
          </plist>
          EOF
          
          xcodebuild -exportArchive \
            -archivePath "build/MyApp.xcarchive" \
            -exportOptionsPlist "build/ExportOptions.plist" \
            -exportPath "build/Export" \
            | xcbeautify

      # ── Upload IPA artifact ──
      - name: Upload IPA
        uses: actions/upload-artifact@v4
        with:
          name: release-ipa-${{ env.VERSION }}-${{ env.BUILD_NUMBER }}
          path: build/Export/*.ipa
          retention-days: 30

      # ── Cleanup ──
      - name: Cleanup Keychain
        if: always()
        run: |
          security delete-keychain "build.keychain" 2>/dev/null || true
          rm -f ~/Library/MobileDevice/Provisioning\ Profiles/build.mobileprovision

    outputs:
      version: ${{ env.VERSION }}
      build_number: ${{ env.BUILD_NUMBER }}


  # ─────────────────────────────────────────────────────────
  # STEP 5: DEPLOY TO TESTFLIGHT
  # Upload cho QA team test trước khi approve merge
  # ─────────────────────────────────────────────────────────
  deploy-testflight:
    name: "✈️ Deploy to TestFlight"
    runs-on: macos-15
    timeout-minutes: 20
    needs: [archive]

    steps:
      - uses: actions/checkout@v4

      # ── Download IPA ──
      - name: Download IPA
        uses: actions/download-artifact@v4
        with:
          name: release-ipa-${{ needs.archive.outputs.version }}-${{ needs.archive.outputs.build_number }}
          path: build/Export

      # ── Upload to App Store Connect ──
      - name: Upload to TestFlight
        env:
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          ASC_PRIVATE_KEY: ${{ secrets.ASC_PRIVATE_KEY }}
        run: |
          mkdir -p ~/.private_keys
          echo "$ASC_PRIVATE_KEY" > \
            ~/.private_keys/AuthKey_${ASC_KEY_ID}.p8
          
          xcrun altool --upload-app \
            --type ios \
            --file build/Export/*.ipa \
            --apiKey "$ASC_KEY_ID" \
            --apiIssuer "$ASC_ISSUER_ID"
          
          rm -rf ~/.private_keys

      # ── Notify team ──
      - name: Notify Slack
        uses: slackapi/slack-github-action@v2
        with:
          webhook: ${{ secrets.SLACK_WEBHOOK }}
          webhook-type: incoming-webhook
          payload: |
            {
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "✈️ *TestFlight build ready*\n• Version: `${{ needs.archive.outputs.version }}` (${{ needs.archive.outputs.build_number }})\n• PR: <${{ github.event.pull_request.html_url }}|#${{ github.event.pull_request.number }}>\n• Please test and approve the PR when ready."
                  }
                }
              ]
            }


  # ─────────────────────────────────────────────────────────
  # STEP 6: PR STATUS SUMMARY
  # Comment kết quả lên PR
  # ─────────────────────────────────────────────────────────
  pr-summary:
    name: "📋 PR Summary"
    runs-on: ubuntu-latest
    if: always()
    needs: [lint, build-and-test, security, coverage-gate, ui-tests, archive, deploy-testflight]

    steps:
      - name: Post PR Comment
        uses: actions/github-script@v7
        with:
          script: |
            const jobs = {
              lint:             '${{ needs.lint.result }}',
              build_test:       '${{ needs.build-and-test.result }}',
              security:         '${{ needs.security.result }}',
              coverage_gate:    '${{ needs.coverage-gate.result }}',
              ui_tests:         '${{ needs.ui-tests.result }}',
              archive:          '${{ needs.archive.result }}',
              deploy_testflight:'${{ needs.deploy-testflight.result }}'
            };
            
            const icon = (s) => s === 'success' ? '✅' : s === 'skipped' ? '⏭️' : '❌';
            const coverage = '${{ needs.build-and-test.outputs.coverage }}';
            
            const body = `## 🚀 Release PR Check Results
            
            | Step | Status |
            |------|--------|
            | Lint + Static Analysis | ${icon(jobs.lint)} ${jobs.lint} |
            | Build + Unit Test | ${icon(jobs.build_test)} ${jobs.build_test} |
            | Security Scan | ${icon(jobs.security)} ${jobs.security} |
            | Coverage Gate (≥${{ env.MINIMUM_COVERAGE }}%) | ${icon(jobs.coverage_gate)} ${coverage}% |
            | UI Tests | ${icon(jobs.ui_tests)} ${jobs.ui_tests} |
            | Archive + IPA | ${icon(jobs.archive)} ${jobs.archive} |
            | TestFlight Deploy | ${icon(jobs.deploy_testflight)} ${jobs.deploy_testflight} |
            
            **Version:** ${{ needs.archive.outputs.version }} (${{ needs.archive.outputs.build_number }})
            `;
            
            // Tìm comment cũ và update thay vì tạo mới
            const { data: comments } = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number
            });
            
            const existing = comments.find(c => 
              c.body.includes('Release PR Check Results') && 
              c.user.type === 'Bot'
            );
            
            if (existing) {
              await github.rest.issues.updateComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                comment_id: existing.id,
                body
              });
            } else {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body
              });
            }


# ═══════════════════════════════════════════════════════════
# POST-MERGE WORKFLOW
# Chạy SAU khi PR được merge vào main
# ═══════════════════════════════════════════════════════════
---
# .github/workflows/post-merge-main.yml
name: "🏷️ Post-Merge: main"

on:
  push:
    branches: [main]

jobs:
  tag-and-release:
    name: "🏷️ Auto Tag + GitHub Release"
    runs-on: ubuntu-latest
    timeout-minutes: 5

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # ── Đọc version từ project ──
      - name: Get Version
        id: version
        run: |
          # Đọc từ file config hoặc Info.plist
          # Ví dụ đơn giản: đọc từ file VERSION
          VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "🏷️ Tagging v${VERSION}"

      # ── Tạo git tag ──
      - name: Create Tag
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          
          TAG="v${{ steps.version.outputs.version }}"
          
          # Kiểm tra tag đã tồn tại chưa
          if git rev-parse "$TAG" >/dev/null 2>&1; then
            echo "⚠️ Tag $TAG already exists, skipping"
          else
            git tag -a "$TAG" -m "Release $TAG"
            git push origin "$TAG"
            echo "✅ Created tag $TAG"
          fi

      # ── GitHub Release với auto changelog ──
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: "v${{ steps.version.outputs.version }}"
          generate_release_notes: true
          draft: false

  # ── Cleanup: xóa branch develop cũ (optional) ──
  notify:
    name: "📢 Notify Release"
    runs-on: ubuntu-latest
    needs: [tag-and-release]

    steps:
      - name: Slack Notification
        uses: slackapi/slack-github-action@v2
        with:
          webhook: ${{ secrets.SLACK_WEBHOOK }}
          webhook-type: incoming-webhook
          payload: |
            {
              "text": "🎉 *v${{ needs.tag-and-release.outputs.version }}* has been merged to main and tagged!"
            }
```

---

### Tổng quan Flow

Để mình vẽ ra flow tổng quan trước, sau đó đi chi tiết từng step.

![Uploading <svg width="100%" viewBox="0 0 680 820" xmlns="http://www.w3.org/2000/svg">
<defs>
  <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
    <path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
  </marker>
</defs>

<!-- Title area -->
<text x="340" y="30" text-anchor="middle" style="fill:rgb(20, 20, 19);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:14px;font-weight:500;text-anchor:middle;dominant-baseline:auto">PR workflow: develop → main</text>

<!-- Step 1: PR Created -->
<g onclick="sendPrompt('Chi tiết step tạo PR develop to main')" style="fill:rgb(0, 0, 0);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto">
  <rect x="220" y="52" width="240" height="50" rx="8" stroke-width="0.5" style="fill:rgb(241, 239, 232);stroke:rgb(95, 94, 90);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="340" y="70" text-anchor="middle" dominant-baseline="central" style="fill:rgb(68, 68, 65);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:14px;font-weight:500;text-anchor:middle;dominant-baseline:central">PR created</text>
  <text x="340" y="88" text-anchor="middle" dominant-baseline="central" style="fill:rgb(95, 94, 90);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:middle;dominant-baseline:central">develop → main</text>
</g>

<line x1="340" y1="102" x2="340" y2="130" marker-end="url(#arrow)" style="fill:none;stroke:rgb(115, 114, 108);color:rgb(0, 0, 0);stroke-width:1.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>

<!-- Step 2: Lint + Static Analysis (parallel) -->
<g onclick="sendPrompt('Chi tiết SwiftLint và static analysis trong CI')" style="fill:rgb(0, 0, 0);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto">
  <rect x="40" y="130" width="190" height="50" rx="8" stroke-width="0.5" style="fill:rgb(225, 245, 238);stroke:rgb(15, 110, 86);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="135" y="148" text-anchor="middle" dominant-baseline="central" style="fill:rgb(8, 80, 65);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:14px;font-weight:500;text-anchor:middle;dominant-baseline:central">Lint + analysis</text>
  <text x="135" y="166" text-anchor="middle" dominant-baseline="central" style="fill:rgb(15, 110, 86);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:middle;dominant-baseline:central">SwiftLint, Periphery</text>
</g>

<!-- Step 3: Build + Test (parallel) -->
<g onclick="sendPrompt('Chi tiết build và test trong CI iOS')" style="fill:rgb(0, 0, 0);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto">
  <rect x="250" y="130" width="190" height="50" rx="8" stroke-width="0.5" style="fill:rgb(238, 237, 254);stroke:rgb(83, 74, 183);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="345" y="148" text-anchor="middle" dominant-baseline="central" style="fill:rgb(60, 52, 137);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:14px;font-weight:500;text-anchor:middle;dominant-baseline:central">Build + test</text>
  <text x="345" y="166" text-anchor="middle" dominant-baseline="central" style="fill:rgb(83, 74, 183);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:middle;dominant-baseline:central">xcodebuild, XCTest</text>
</g>

<!-- Step 4: Security scan (parallel) -->
<g onclick="sendPrompt('Chi tiết security scan trong CI iOS')" style="fill:rgb(0, 0, 0);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto">
  <rect x="460" y="130" width="180" height="50" rx="8" stroke-width="0.5" style="fill:rgb(250, 236, 231);stroke:rgb(153, 60, 29);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="550" y="148" text-anchor="middle" dominant-baseline="central" style="fill:rgb(113, 43, 19);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:14px;font-weight:500;text-anchor:middle;dominant-baseline:central">Security scan</text>
  <text x="550" y="166" text-anchor="middle" dominant-baseline="central" style="fill:rgb(153, 60, 29);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:middle;dominant-baseline:central">Dependencies, secrets</text>
</g>

<!-- Parallel bracket lines -->
<line x1="340" y1="120" x2="135" y2="130" stroke="var(--s)" stroke-width="0.5" style="fill:rgb(0, 0, 0);stroke:rgb(61, 61, 58);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
<line x1="340" y1="120" x2="345" y2="130" stroke="var(--s)" stroke-width="0.5" style="fill:rgb(0, 0, 0);stroke:rgb(61, 61, 58);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
<line x1="340" y1="120" x2="550" y2="130" stroke="var(--s)" stroke-width="0.5" style="fill:rgb(0, 0, 0);stroke:rgb(61, 61, 58);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>

<!-- Converge lines -->
<line x1="135" y1="180" x2="340" y2="210" stroke="var(--s)" stroke-width="0.5" style="fill:rgb(0, 0, 0);stroke:rgb(61, 61, 58);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
<line x1="345" y1="180" x2="340" y2="210" stroke="var(--s)" stroke-width="0.5" style="fill:rgb(0, 0, 0);stroke:rgb(61, 61, 58);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
<line x1="550" y1="180" x2="340" y2="210" stroke="var(--s)" stroke-width="0.5" style="fill:rgb(0, 0, 0);stroke:rgb(61, 61, 58);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>

<!-- Step 5: Code Coverage Gate -->
<g onclick="sendPrompt('Cách enforce code coverage gate trong CI')" style="fill:rgb(0, 0, 0);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto">
  <rect x="220" y="210" width="240" height="50" rx="8" stroke-width="0.5" style="fill:rgb(225, 245, 238);stroke:rgb(15, 110, 86);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="340" y="228" text-anchor="middle" dominant-baseline="central" style="fill:rgb(8, 80, 65);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:14px;font-weight:500;text-anchor:middle;dominant-baseline:central">Coverage gate</text>
  <text x="340" y="246" text-anchor="middle" dominant-baseline="central" style="fill:rgb(15, 110, 86);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:middle;dominant-baseline:central">≥ 80% line coverage</text>
</g>

<line x1="340" y1="260" x2="340" y2="290" marker-end="url(#arrow)" style="fill:none;stroke:rgb(115, 114, 108);color:rgb(0, 0, 0);stroke-width:1.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>

<!-- Step 6: UI Test -->
<g onclick="sendPrompt('Chi tiết UI testing XCUITest trong CI')" style="fill:rgb(0, 0, 0);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto">
  <rect x="220" y="290" width="240" height="50" rx="8" stroke-width="0.5" style="fill:rgb(238, 237, 254);stroke:rgb(83, 74, 183);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="340" y="308" text-anchor="middle" dominant-baseline="central" style="fill:rgb(60, 52, 137);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:14px;font-weight:500;text-anchor:middle;dominant-baseline:central">UI tests</text>
  <text x="340" y="326" text-anchor="middle" dominant-baseline="central" style="fill:rgb(83, 74, 183);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:middle;dominant-baseline:central">XCUITest, snapshot</text>
</g>

<line x1="340" y1="340" x2="340" y2="370" marker-end="url(#arrow)" style="fill:none;stroke:rgb(115, 114, 108);color:rgb(0, 0, 0);stroke-width:1.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>

<!-- Step 7: Build Archive -->
<g onclick="sendPrompt('Chi tiết archive IPA trong CI')" style="fill:rgb(0, 0, 0);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto">
  <rect x="220" y="370" width="240" height="50" rx="8" stroke-width="0.5" style="fill:rgb(230, 241, 251);stroke:rgb(24, 95, 165);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="340" y="388" text-anchor="middle" dominant-baseline="central" style="fill:rgb(12, 68, 124);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:14px;font-weight:500;text-anchor:middle;dominant-baseline:central">Archive + export IPA</text>
  <text x="340" y="406" text-anchor="middle" dominant-baseline="central" style="fill:rgb(24, 95, 165);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:middle;dominant-baseline:central">Code signing, .ipa</text>
</g>

<line x1="340" y1="420" x2="340" y2="450" marker-end="url(#arrow)" style="fill:none;stroke:rgb(115, 114, 108);color:rgb(0, 0, 0);stroke-width:1.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>

<!-- Step 8: Deploy TestFlight -->
<g onclick="sendPrompt('Chi tiết deploy TestFlight trong CI')" style="fill:rgb(0, 0, 0);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto">
  <rect x="220" y="450" width="240" height="50" rx="8" stroke-width="0.5" style="fill:rgb(250, 238, 218);stroke:rgb(133, 79, 11);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="340" y="468" text-anchor="middle" dominant-baseline="central" style="fill:rgb(99, 56, 6);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:14px;font-weight:500;text-anchor:middle;dominant-baseline:central">Deploy TestFlight</text>
  <text x="340" y="486" text-anchor="middle" dominant-baseline="central" style="fill:rgb(133, 79, 11);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:middle;dominant-baseline:central">Upload + notify QA</text>
</g>

<line x1="340" y1="500" x2="340" y2="530" marker-end="url(#arrow)" style="fill:none;stroke:rgb(115, 114, 108);color:rgb(0, 0, 0);stroke-width:1.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>

<!-- Step 9: Manual QA Approval -->
<g onclick="sendPrompt('Cách cấu hình manual approval trong GitHub Actions')" style="fill:rgb(0, 0, 0);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto">
  <rect x="220" y="530" width="240" height="50" rx="8" stroke-width="0.5" style="fill:rgb(250, 236, 231);stroke:rgb(153, 60, 29);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="340" y="548" text-anchor="middle" dominant-baseline="central" style="fill:rgb(113, 43, 19);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:14px;font-weight:500;text-anchor:middle;dominant-baseline:central">QA approval</text>
  <text x="340" y="566" text-anchor="middle" dominant-baseline="central" style="fill:rgb(153, 60, 29);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:middle;dominant-baseline:central">Manual review gate</text>
</g>

<line x1="340" y1="580" x2="340" y2="610" marker-end="url(#arrow)" style="fill:none;stroke:rgb(115, 114, 108);color:rgb(0, 0, 0);stroke-width:1.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>

<!-- Step 10: Merge + Tag -->
<g onclick="sendPrompt('Cách auto tag version sau khi merge')" style="fill:rgb(0, 0, 0);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto">
  <rect x="220" y="610" width="240" height="50" rx="8" stroke-width="0.5" style="fill:rgb(234, 243, 222);stroke:rgb(59, 109, 17);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="340" y="628" text-anchor="middle" dominant-baseline="central" style="fill:rgb(39, 80, 10);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:14px;font-weight:500;text-anchor:middle;dominant-baseline:central">Merge + auto tag</text>
  <text x="340" y="646" text-anchor="middle" dominant-baseline="central" style="fill:rgb(59, 109, 17);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:middle;dominant-baseline:central">v1.2.0, GitHub Release</text>
</g>

<line x1="340" y1="660" x2="340" y2="690" marker-end="url(#arrow)" style="fill:none;stroke:rgb(115, 114, 108);color:rgb(0, 0, 0);stroke-width:1.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>

<!-- Step 11: Post-merge -->
<g onclick="sendPrompt('Chi tiết post-merge actions sau khi merge main')" style="fill:rgb(0, 0, 0);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto">
  <rect x="220" y="690" width="240" height="50" rx="8" stroke-width="0.5" style="fill:rgb(241, 239, 232);stroke:rgb(95, 94, 90);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="340" y="708" text-anchor="middle" dominant-baseline="central" style="fill:rgb(68, 68, 65);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:14px;font-weight:500;text-anchor:middle;dominant-baseline:central">Post-merge</text>
  <text x="340" y="726" text-anchor="middle" dominant-baseline="central" style="fill:rgb(95, 94, 90);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:middle;dominant-baseline:central">Notify, cleanup branches</text>
</g>

<!-- Side annotations -->
<text x="46" y="240" fill="var(--color-text-success)" style="fill:rgb(61, 61, 58);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:start;dominant-baseline:auto">Parallel jobs</text>
<line x1="40" y1="148" x2="40" y2="180" stroke-width="0.5" style="fill:none;stroke:rgb(115, 114, 108);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-dasharray:4px, 3px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
<rect x="34" y="126" width="12" height="58" rx="3" fill="none" stroke="var(--color-text-success)" stroke-width="0.5" stroke-dasharray="3 3" style="fill:none;stroke:rgb(38, 91, 25);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-dasharray:3px, 3px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>

<text x="500" y="456" fill="var(--color-text-warning)" style="fill:rgb(61, 61, 58);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:start;dominant-baseline:auto">On merge approval</text>

<text x="500" y="548" fill="var(--color-text-danger)" style="fill:rgb(61, 61, 58);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:start;dominant-baseline:auto">Requires human</text>

<!-- Legend -->
<g transform="translate(40, 770)" style="fill:rgb(0, 0, 0);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto">
  <rect x="0" y="0" width="14" height="14" rx="3" stroke-width="0.5" style="fill:rgb(225, 245, 238);stroke:rgb(15, 110, 86);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="20" y="11" style="fill:rgb(61, 61, 58);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:start;dominant-baseline:auto">Quality gates</text>
  <rect x="130" y="0" width="14" height="14" rx="3" stroke-width="0.5" style="fill:rgb(238, 237, 254);stroke:rgb(83, 74, 183);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="150" y="11" style="fill:rgb(61, 61, 58);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:start;dominant-baseline:auto">Build + test</text>
  <rect x="250" y="0" width="14" height="14" rx="3" stroke-width="0.5" style="fill:rgb(230, 241, 251);stroke:rgb(24, 95, 165);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="270" y="11" style="fill:rgb(61, 61, 58);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:start;dominant-baseline:auto">Packaging</text>
  <rect x="360" y="0" width="14" height="14" rx="3" stroke-width="0.5" style="fill:rgb(250, 238, 218);stroke:rgb(133, 79, 11);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="380" y="11" style="fill:rgb(61, 61, 58);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:start;dominant-baseline:auto">Distribution</text>
  <rect x="480" y="0" width="14" height="14" rx="3" stroke-width="0.5" style="fill:rgb(250, 236, 231);stroke:rgb(153, 60, 29);color:rgb(0, 0, 0);stroke-width:0.5px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:16px;font-weight:400;text-anchor:start;dominant-baseline:auto"/>
  <text x="500" y="11" style="fill:rgb(61, 61, 58);stroke:none;color:rgb(0, 0, 0);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;opacity:1;font-family:&quot;Anthropic Sans&quot;, -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, sans-serif;font-size:12px;font-weight:400;text-anchor:start;dominant-baseline:auto">Approval</text>
</g>
</svg>pr_develop_to_main_flow.svg…]()


Giờ đi chi tiết từng step với workflow YAML hoàn chỉnh:

## Giải thích chi tiết từng Step

### Step 1 — Parallel Quality Gates (3 jobs chạy đồng thời)

Ba job `lint`, `build-and-test`, `security` không có `needs` nên GitHub Actions chạy song song, giảm tổng thời gian từ ~50 phút xuống ~30 phút.

**1A — Lint + Static Analysis:** SwiftLint kiểm tra coding convention, SwiftFormat đảm bảo format nhất quán, Periphery phát hiện dead code. Trick hay là dùng `git diff` để chỉ lint file thay đổi trong PR — vừa nhanh vừa giúp team focus vào code mới.

**1B — Build + Unit Test:** Build ở simulator mode (`CODE_SIGNING_ALLOWED=NO`) không cần certificate. `COMPILER_INDEX_STORE_ENABLE=NO` tắt indexing, tiết kiệm ~20% build time. Output `coverage` truyền sang job sau qua `outputs`.

**1C — Security Scan:** TruffleHog quét secret bị commit nhầm, chỉ scan diff giữa base và head SHA. `swift package audit` kiểm tra vulnerability trong SPM dependencies.

### Step 2 — Coverage Gate

Job nhẹ chạy trên `ubuntu-latest` (rẻ hơn macOS runner). Lấy `coverage` output từ job trước, so sánh với threshold. Fail sớm nếu coverage thấp, không cần chờ UI test.

### Step 3 — UI Tests

Chạy sau `build-and-test` thành công. Download `DerivedData` artifact để dùng lại build sản phẩm — `test-without-building` chạy nhanh hơn nhiều so với build lại từ đầu. Boot simulator trước khi chạy test.

### Step 4 — Archive + Export IPA

**Chỉ chạy khi TẤT CẢ 5 job trước pass** (`needs: [lint, build-and-test, security, coverage-gate, ui-tests]`). Đây là bước tốn thời gian nhất vì cần code signing:

```
Tạo temp keychain → Import .p12 certificate → Install provisioning profile
→ Archive (Release config) → Export IPA → Cleanup keychain
```

Version lấy từ project settings, build number dùng `github.run_number` (tự tăng mỗi run).

### Step 5 — Deploy TestFlight

Upload IPA lên App Store Connect bằng `xcrun altool` + API Key. Gửi Slack notification cho QA team biết build đã sẵn sàng test. **QA test trên TestFlight trước khi approve merge PR.**

### Step 6 — PR Summary Comment

Job cuối cùng (`if: always()`) tổng hợp kết quả tất cả step và comment lên PR dưới dạng bảng. Nếu đã có comment cũ thì update thay vì tạo mới — tránh spam PR.

### Step 7 — Post-Merge (workflow riêng)

Sau khi PR được approve và merge, workflow `post-merge-main.yml` tự động tạo git tag `v1.2.0` và GitHub Release với auto-generated changelog.

---

## Branch Protection Rules cần thiết

Để enforce pipeline này, cần config Branch Protection trên `main`:

```
Settings → Branches → Add rule → Branch name: main

✅ Require a pull request before merging
   ✅ Require approvals: 2 (hoặc tuỳ team size)
   ✅ Dismiss stale PR approvals when new commits are pushed
   
✅ Require status checks to pass before merging
   Required checks:
   - 🧹 Lint + Static Analysis
   - 🔨 Build + Unit Test
   - 🔒 Security Scan
   - 📊 Coverage Gate
   - 📱 UI Tests
   - 📦 Archive + Export IPA
   
✅ Require branches to be up to date before merging
✅ Require conversation resolution before merging
✅ Do not allow bypassing the above settings
```

Bất cứ bước nào fail, nút **Merge** trên GitHub sẽ bị disable — không ai merge được code lỗi vào `main`.

---

## Tóm tắt thứ tự dependency

```
PR Created
  ├── Lint           ─┐
  ├── Build + Test   ─┼── (parallel)
  └── Security       ─┘
         │
    Coverage Gate  ───→  UI Tests
         │                  │
         └──────┬───────────┘
                │
         Archive + IPA
                │
        Deploy TestFlight
                │
        QA Test + Approve (manual)
                │
           Merge PR
                │
        Auto Tag + Release (post-merge)
```

Bấm vào bất kỳ box nào trên diagram ở trên nếu muốn mình đi sâu hơn vào step cụ thể nhé!
