# Proxy Settings UI Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Polish ProxySettingsView to match the "precision minimal" navy theme with subtle gradient + cards, and add lightweight validation helpers for settings fields.

**Architecture:** Add a small validation helper for control address and ports, then update `ProxySettingsView` to use a two-card layout with hints and inline errors. Keep persistence and auto-apply behavior unchanged.

**Tech Stack:** SwiftUI (macOS 14), Swift 5.9, XCTest.

---

### Task 1: Add validation helper for control address + port

**Files:**
- Create: `mac/ProxyMac/ProxyMac/Services/ProxySettingsValidation.swift`
- Test: `mac/ProxyMac/ProxyMacTests/ProxySettingsValidationTests.swift`
- Modify: `mac/ProxyMac/ProxyMac.xcodeproj/project.pbxproj`

**Step 1: Write the failing tests**

Create `mac/ProxyMac/ProxyMacTests/ProxySettingsValidationTests.swift`:

```swift
import XCTest
@testable import ProxyMac

final class ProxySettingsValidationTests: XCTestCase {
    func testPortValidationRejectsOutOfRange() {
        XCTAssertNotNil(ProxySettingsValidation.portError(0))
        XCTAssertNotNil(ProxySettingsValidation.portError(70000))
    }

    func testPortValidationAcceptsValid() {
        XCTAssertNil(ProxySettingsValidation.portError(1))
        XCTAssertNil(ProxySettingsValidation.portError(65535))
    }

    func testControlAddressValidationRejectsMissingPort() {
        XCTAssertNotNil(ProxySettingsValidation.controlAddressError("localhost"))
        XCTAssertNotNil(ProxySettingsValidation.controlAddressError(""))
    }

    func testControlAddressValidationRejectsInvalidPort() {
        XCTAssertNotNil(ProxySettingsValidation.controlAddressError("localhost:0"))
        XCTAssertNotNil(ProxySettingsValidation.controlAddressError("localhost:70000"))
        XCTAssertNotNil(ProxySettingsValidation.controlAddressError("localhost:abc"))
    }

    func testControlAddressValidationAcceptsValid() {
        XCTAssertNil(ProxySettingsValidation.controlAddressError("127.0.0.1:5959"))
        XCTAssertNil(ProxySettingsValidation.controlAddressError("localhost:8080"))
    }
}
```

**Step 2: Run tests to verify failure**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: FAIL (missing `ProxySettingsValidation`).

**Step 3: Implement minimal validation helper**

Create `mac/ProxyMac/ProxyMac/Services/ProxySettingsValidation.swift`:

```swift
import Foundation

enum ProxySettingsValidation {
    static func portError(_ port: Int) -> String? {
        guard (1...65535).contains(port) else {
            return "Port must be between 1 and 65535"
        }
        return nil
    }

    static func controlAddressError(_ address: String) -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Control address is required" }
        guard let colonIndex = trimmed.lastIndex(of: ":") else {
            return "Use host:port"
        }
        let host = trimmed[..<colonIndex]
        let portStr = trimmed[trimmed.index(after: colonIndex)...]
        guard !host.isEmpty, let port = Int(portStr) else {
            return "Use host:port"
        }
        return portError(port)
    }
}
```

**Step 4: Run tests to verify pass**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: PASS.

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Services/ProxySettingsValidation.swift mac/ProxyMac/ProxyMacTests/ProxySettingsValidationTests.swift mac/ProxyMac/ProxyMac.xcodeproj/project.pbxproj
git commit -m "feat: add proxy settings validation"
```

---

### Task 2: Apply UI polish to ProxySettingsView

**Files:**
- Modify: `mac/ProxyMac/ProxyMac/Views/ProxySettingsView.swift`
- Modify: `mac/ProxyMac/ProxyMac/Views/RulesSplitView.swift` (to keep sheet width and title if needed)
- Modify: `mac/ProxyMac/ProxyMac.xcodeproj/project.pbxproj` (if adding new supporting view/style file)
- Test: `mac/ProxyMac/ProxyMacTests/ProxyMacTests.swift` (add a simple validation wiring smoke test if needed)

**Step 1: Write failing test**

Add a small test in `mac/ProxyMac/ProxyMacTests/ProxyMacTests.swift` to ensure validation is used in the view:

```swift
func testValidationReportsBadControlAddress() {
    XCTAssertNotNil(ProxySettingsValidation.controlAddressError("localhost"))
}
```

**Step 2: Run tests to verify fail**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: FAIL if validation helper not yet referenced in tests.

**Step 3: Update ProxySettingsView**

Replace layout with a two-card design, subtle gradient background, and helper/error text. Example structure:

```swift
@available(macOS 14.0, *)
struct ProxySettingsView: View {
    @ObservedObject var settings: ProxySettings

    var body: some View {
        VStack(spacing: 16) {
            header
            controlCard
            listenersCard
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 520)
        .background(LinearGradient(...))
    }

    private var header: some View { ... }
    private var controlCard: some View { ... }
    private var listenersCard: some View { ... }
}
```

Include helper text under fields (port range, example). Use inline error text when `ProxySettingsValidation` returns a message.

**Step 4: Run tests to verify pass**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: PASS.

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Views/ProxySettingsView.swift mac/ProxyMac/ProxyMacTests/ProxyMacTests.swift
# plus any new style helpers if added
git commit -m "feat: polish proxy settings ui"
```

---

### Task 3: Optional small style helpers (if needed)

**Files:**
- Create: `mac/ProxyMac/ProxyMac/Views/Style/FieldCard.swift` (optional)
- Modify: `mac/ProxyMac/ProxyMac.xcodeproj/project.pbxproj`

**Step 1: Write minimal test**

No test required if purely UI styling without logic.

**Step 2: Implement helper**

Small SwiftUI view to reduce duplication for card styling.

**Step 3: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Views/Style/FieldCard.swift mac/ProxyMac/ProxyMac.xcodeproj/project.pbxproj
git commit -m "refactor: add settings ui card helper"
```

---

## Notes
- Keep everything ASCII.
- Don’t change persistence or proxy behavior.
- Use Source Sans 3 if available (system fallback is fine).
