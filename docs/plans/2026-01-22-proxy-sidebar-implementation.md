# Proxy Sidebar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a right-side status/actions rail showing proxy state, listener summary, and Start/Stop + Apply + Health Check actions.

**Architecture:** Extend the main detail view to include a right rail composed of three cards. Use existing `ProxyCoreActions` + `ProxySettings` for state and actions. Add a lightweight health check method to `ProxyCoreController` if needed.

**Tech Stack:** SwiftUI (macOS 14), Swift 5.9, XCTest.

---

### Task 1: Add health check action helper

**Files:**
- Modify: `mac/ProxyMac/ProxyMac/Services/ProxyCoreActions.swift`
- Test: `mac/ProxyMac/ProxyMacTests/ProxyCoreActionsTests.swift`

**Step 1: Write failing test**

Add test in `mac/ProxyMac/ProxyMacTests/ProxyCoreActionsTests.swift`:

```swift
@MainActor
func testHealthCheckCallsController() async {
    let controller = FakeProxyCoreController(state: .running)
    let settings = ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)

    await ProxyCoreActions.healthCheck(controller: controller, settings: settings)

    XCTAssertEqual(controller.healthCheckCount, 1)
}
```

Update fake controller in the same test file to track calls:

```swift
private(set) var healthCheckCount = 0
func healthCheck() async { healthCheckCount += 1 }
```

**Step 2: Run tests to verify fail**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: FAIL (missing API).

**Step 3: Implement minimal API**

In `ProxyCoreActions.swift`:

```swift
static func healthCheck(controller: ProxyCoreControlling, settings: ProxySettings) async {
    await controller.healthCheck()
}
```

Extend `ProxyCoreControlling` protocol with:

```swift
func healthCheck() async
```

Implement in `ProxyCoreController`:

```swift
func healthCheck() async {
    do {
        try await controlClient.health()
        state = .running
    } catch {
        state = .failed(error.localizedDescription)
    }
}
```

**Step 4: Run tests to verify pass**

Run the same `xcodebuild` command. Expected: PASS.

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Services/ProxyCoreActions.swift mac/ProxyMac/ProxyMac/Services/ProxyCoreController.swift mac/ProxyMac/ProxyMacTests/ProxyCoreActionsTests.swift
git commit -m "feat: add health check action"
```

---

### Task 2: Add right sidebar layout

**Files:**
- Modify: `mac/ProxyMac/ProxyMac/Views/RulesSplitView.swift`
- Create: `mac/ProxyMac/ProxyMac/Views/ProxySidebarView.swift`
- Modify: `mac/ProxyMac/ProxyMac.xcodeproj/project.pbxproj`
- Test: `mac/ProxyMac/ProxyMacTests/RulesViewTests.swift`

**Step 1: Write failing test**

Add a minimal load test in `mac/ProxyMac/ProxyMacTests/RulesViewTests.swift`:

```swift
func testProxySidebarViewLoads() {
    _ = ProxySidebarView(settings: ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!), controller: ProxyCoreController())
}
```

**Step 2: Run tests to verify fail**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: FAIL (missing `ProxySidebarView`).

**Step 3: Implement `ProxySidebarView`**

Create `ProxySidebarView.swift` with three cards and fixed width (240-260pt). Use the same card styling as `ProxySettingsView` (rounded rect, light shadow, thin border). Include:
- Status card with dot + status text + control address
- Listeners card with HTTP/SOCKS5 port + enabled state
- Actions card with Start/Stop (primary), Apply, Health Check (secondary)

**Step 4: Wire into `RulesSplitView`**

Replace detail content with a horizontal stack:

```swift
HStack(spacing: 16) {
    ruleDetailView
    ProxySidebarView(settings: settings, controller: controller)
}
```

**Step 5: Run tests to verify pass**

Run the same `xcodebuild` command. Expected: PASS.

**Step 6: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Views/ProxySidebarView.swift mac/ProxyMac/ProxyMac/Views/RulesSplitView.swift mac/ProxyMac/ProxyMacTests/RulesViewTests.swift mac/ProxyMac/ProxyMac.xcodeproj/project.pbxproj
git commit -m "feat: add proxy sidebar"
```

---

### Task 3: Optional styling helper

**Files:**
- Create: `mac/ProxyMac/ProxyMac/Views/Style/CardView.swift` (optional)
- Modify: `mac/ProxyMac/ProxyMac.xcodeproj/project.pbxproj`

**Step 1: Implement helper**

Add a small reusable `CardView` to standardize padding, border, and shadow.

**Step 2: Use in `ProxySidebarView`**

Replace repeated background/stroke code with `CardView`.

**Step 3: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Views/Style/CardView.swift mac/ProxyMac/ProxyMac/Views/ProxySidebarView.swift mac/ProxyMac/ProxyMac.xcodeproj/project.pbxproj
git commit -m "refactor: add card view helper"
```
