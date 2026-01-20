# Rules UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a full rules configuration UI (list + editor), import/export, and auto/manual sort with drag reordering.

**Architecture:** SwiftUI `NavigationSplitView` drives a sidebar list and detail editor backed by SwiftData `Rule` model. Sorting uses a pure helper for auto priority and manual `order` fields, with a global sort mode stored in `@AppStorage`.

**Tech Stack:** SwiftUI, SwiftData (macOS 14+), XCTest, XcodeGen.

---

### Task 1: Extend Rule model + JSON import/export

**Files:**
- Modify: `mac/ProxyMac/ProxyMac/Models/Rule.swift`
- Modify: `mac/ProxyMac/ProxyMac/Services/ImportExport.swift`
- Modify: `mac/ProxyMac/ProxyMacTests/ImportExportTests.swift`

**Step 1: Write the failing test**

```swift
import SwiftData
import XCTest
@testable import ProxyMac

@available(macOS 14.0, *)
final class ImportExportTests: XCTestCase {
    func testExportImportRoundTrip() throws {
        let container = try ModelContainer(for: Rule.self)
        let context = ModelContext(container)

        let rule = Rule(host: "api.dev.test", pathPrefix: "/v1/", upstream: "https://api.example.com")
        rule.enabled = false
        rule.note = "note"
        rule.order = 42
        context.insert(rule)

        let data = try RuleJSON.export([rule])
        let decoded = try RuleJSON.importRules(data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].host, "api.dev.test")
        XCTAssertEqual(decoded[0].enabled, false)
        XCTAssertEqual(decoded[0].note, "note")
        XCTAssertEqual(decoded[0].order, 42)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`
Expected: FAIL with “Value of type 'Rule' has no member 'enabled' / 'note' / 'order'”

**Step 3: Write minimal implementation**

```swift
@available(macOS 14.0, *)
@Model
final class Rule: Codable {
    var host: String
    var pathPrefix: String
    var upstream: String
    var enabled: Bool
    var note: String?
    var order: Int

    init(host: String, pathPrefix: String, upstream: String, enabled: Bool = true, note: String? = nil, order: Int = 0) {
        self.host = host
        self.pathPrefix = pathPrefix
        self.upstream = upstream
        self.enabled = enabled
        self.note = note
        self.order = order
    }

    enum CodingKeys: String, CodingKey {
        case host, pathPrefix, upstream, enabled, note, order
    }

    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let host = try container.decode(String.self, forKey: .host)
        let pathPrefix = try container.decode(String.self, forKey: .pathPrefix)
        let upstream = try container.decode(String.self, forKey: .upstream)
        let enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        let note = try container.decodeIfPresent(String.self, forKey: .note)
        let order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        self.init(host: host, pathPrefix: pathPrefix, upstream: upstream, enabled: enabled, note: note, order: order)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(host, forKey: .host)
        try container.encode(pathPrefix, forKey: .pathPrefix)
        try container.encode(upstream, forKey: .upstream)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(order, forKey: .order)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`
Expected: PASS

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Models/Rule.swift mac/ProxyMac/ProxyMac/Services/ImportExport.swift mac/ProxyMac/ProxyMacTests/ImportExportTests.swift
git commit -m "feat: extend rule model and JSON export"
```

---

### Task 2: Sorting helpers for auto/manual

**Files:**
- Create: `mac/ProxyMac/ProxyMac/Models/RuleSorting.swift`
- Create: `mac/ProxyMac/ProxyMacTests/RuleSortingTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import ProxyMac

@available(macOS 14.0, *)
final class RuleSortingTests: XCTestCase {
    func testAutoSortPrioritizesSpecificity() {
        let exact = Rule(host: "api.dev.test", pathPrefix: "/v1/", upstream: "https://a")
        let wildcard = Rule(host: "*.dev.test", pathPrefix: "/", upstream: "https://b")
        let longerPath = Rule(host: "api.dev.test", pathPrefix: "/v1/users/", upstream: "https://c")

        let sorted = RuleSorting.autoSort([wildcard, exact, longerPath])
        XCTAssertEqual(sorted.first?.pathPrefix, "/v1/users/")
        XCTAssertEqual(sorted[1].host, "api.dev.test")
        XCTAssertEqual(sorted.last?.host, "*.dev.test")
    }

    func testManualSortByOrder() {
        let a = Rule(host: "a.dev.test", pathPrefix: "/", upstream: "https://a", order: 2)
        let b = Rule(host: "b.dev.test", pathPrefix: "/", upstream: "https://b", order: 1)
        let sorted = RuleSorting.manualSort([a, b])
        XCTAssertEqual(sorted.first?.host, "b.dev.test")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`
Expected: FAIL with “Cannot find 'RuleSorting' in scope”

**Step 3: Write minimal implementation**

```swift
import Foundation

@available(macOS 14.0, *)
enum RuleSorting {
    static func autoSort(_ rules: [Rule]) -> [Rule] {
        return rules.sorted { lhs, rhs in
            let lhsSpec = hostSpecificity(lhs.host)
            let rhsSpec = hostSpecificity(rhs.host)
            if lhsSpec != rhsSpec { return lhsSpec > rhsSpec }
            if lhs.pathPrefix.count != rhs.pathPrefix.count { return lhs.pathPrefix.count > rhs.pathPrefix.count }
            return lhs.host < rhs.host
        }
    }

    static func manualSort(_ rules: [Rule]) -> [Rule] {
        return rules.sorted { $0.order < $1.order }
    }

    private static func hostSpecificity(_ host: String) -> Int {
        return host.hasPrefix("*.") ? 0 : 1
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`
Expected: PASS

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Models/RuleSorting.swift mac/ProxyMac/ProxyMacTests/RuleSortingTests.swift
git commit -m "feat: add rule sorting helpers"
```

---

### Task 3: Reorder helper for manual mode

**Files:**
- Modify: `mac/ProxyMac/ProxyMac/Models/RuleSorting.swift`
- Modify: `mac/ProxyMac/ProxyMacTests/RuleSortingTests.swift`

**Step 1: Write the failing test**

```swift
@available(macOS 14.0, *)
func testReassignOrderPreservesListOrder() {
    let a = Rule(host: "a.dev.test", pathPrefix: "/", upstream: "https://a", order: 10)
    let b = Rule(host: "b.dev.test", pathPrefix: "/", upstream: "https://b", order: 20)
    let updated = RuleSorting.reassignOrder([b, a])
    XCTAssertEqual(updated[0].order, 0)
    XCTAssertEqual(updated[1].order, 1)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`
Expected: FAIL with “Value of type 'RuleSorting' has no member 'reassignOrder'”

**Step 3: Write minimal implementation**

```swift
static func reassignOrder(_ rules: [Rule]) -> [Rule] {
    for (index, rule) in rules.enumerated() {
        rule.order = index
    }
    return rules
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`
Expected: PASS

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Models/RuleSorting.swift mac/ProxyMac/ProxyMacTests/RuleSortingTests.swift
git commit -m "feat: add manual reorder helper"
```

---

### Task 4: Rules split view + detail editor

**Files:**
- Create: `mac/ProxyMac/ProxyMac/Views/RulesSplitView.swift`
- Create: `mac/ProxyMac/ProxyMac/Views/RuleRowView.swift`
- Create: `mac/ProxyMac/ProxyMac/Views/RuleDetailView.swift`
- Modify: `mac/ProxyMac/ProxyMac/Views/MainWindow.swift`
- Create: `mac/ProxyMac/ProxyMacTests/RulesViewTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import ProxyMac

final class RulesViewTests: XCTestCase {
    func testRulesSplitViewLoads() {
        _ = RulesSplitView()
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`
Expected: FAIL with “Cannot find 'RulesSplitView' in scope”

**Step 3: Write minimal implementation**

```swift
import SwiftData
import SwiftUI

@available(macOS 14.0, *)
struct RulesSplitView: View {
    @AppStorage("rules.sortMode") private var sortMode = "auto"
    @Environment(\.modelContext) private var context
    @Query(sort: \Rule.order) private var rules: [Rule]
    @State private var selection: Rule?

    private var displayRules: [Rule] {
        sortMode == "manual" ? RuleSorting.manualSort(rules) : RuleSorting.autoSort(rules)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(displayRules) { rule in
                    RuleRowView(rule: rule)
                        .tag(rule)
                }
                .onMove { indices, newOffset in
                    guard sortMode == "manual" else { return }
                    var reordered = displayRules
                    reordered.move(fromOffsets: indices, toOffset: newOffset)
                    _ = RuleSorting.reassignOrder(reordered)
                    try? context.save()
                }
            }
        } detail: {
            if let rule = selection {
                RuleDetailView(rule: rule)
            } else {
                Text("Select a rule")
                    .foregroundStyle(.secondary)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Add") { addRule() }
                Button("Delete") { deleteRule() }
                Divider()
                Picker("Sort Mode", selection: $sortMode) {
                    Text("Auto").tag("auto")
                    Text("Manual").tag("manual")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func addRule() {
        let nextOrder = (rules.map { $0.order }.max() ?? -1) + 1
        let rule = Rule(host: "", pathPrefix: "/", upstream: "", order: nextOrder)
        context.insert(rule)
        selection = rule
        try? context.save()
    }

    private func deleteRule() {
        guard let selection else { return }
        context.delete(selection)
        self.selection = nil
        try? context.save()
    }
}
```

```swift
import SwiftUI

@available(macOS 14.0, *)
struct RuleRowView: View {
    @ObservedObject var rule: Rule

    var body: some View {
        HStack {
            Toggle("", isOn: $rule.enabled)
                .labelsHidden()
            VStack(alignment: .leading) {
                Text(rule.host.isEmpty ? "(host)" : rule.host)
                Text(rule.pathPrefix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(rule.upstream.isEmpty ? "(upstream)" : rule.upstream)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .opacity(rule.enabled ? 1.0 : 0.5)
    }
}
```

```swift
import SwiftUI

@available(macOS 14.0, *)
struct RuleDetailView: View {
    @ObservedObject var rule: Rule

    var body: some View {
        Form {
            TextField("Host", text: $rule.host)
            TextField("Path Prefix", text: $rule.pathPrefix)
            TextField("Upstream", text: $rule.upstream)
            Toggle("Enabled", isOn: $rule.enabled)
            TextEditor(text: Binding($rule.note, replacingNilWith: ""))
                .frame(minHeight: 120)
        }
        .padding()
    }
}

private extension Binding where Value == String? {
    init(_ source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0 }
        )
    }
}
```

Update `MainWindow.swift` to show `RulesSplitView()` instead of placeholder text.

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`
Expected: PASS

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Views/RulesSplitView.swift mac/ProxyMac/ProxyMac/Views/RuleRowView.swift mac/ProxyMac/ProxyMac/Views/RuleDetailView.swift mac/ProxyMac/ProxyMac/Views/MainWindow.swift mac/ProxyMac/ProxyMacTests/RulesViewTests.swift
git commit -m "feat: add rules split view"
```

---

### Task 5: Import/Export UI actions

**Files:**
- Modify: `mac/ProxyMac/ProxyMac/Views/RulesSplitView.swift`
- Create: `mac/ProxyMac/ProxyMac/Services/JSONFileDocument.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import ProxyMac

final class RulesViewTests: XCTestCase {
    func testFileDocumentLoads() {
        _ = JSONFileDocument(data: Data())
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`
Expected: FAIL with “Cannot find 'JSONFileDocument' in scope”

**Step 3: Write minimal implementation**

```swift
import SwiftUI

struct JSONFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init(regularFileWithContents: data)
    }
}
```

Update `RulesSplitView` toolbar to add Import/Export using `fileImporter` and `fileExporter`, calling `RuleJSON.importRules` / `RuleJSON.export`.

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`
Expected: PASS

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Views/RulesSplitView.swift mac/ProxyMac/ProxyMac/Services/JSONFileDocument.swift mac/ProxyMac/ProxyMacTests/RulesViewTests.swift
git commit -m "feat: add import/export actions"
```

---

## Notes
- macOS 14+ required for SwiftData and `NavigationSplitView` behavior used here.
- Sorting mode is stored in `@AppStorage("rules.sortMode")` and defaults to Auto.

