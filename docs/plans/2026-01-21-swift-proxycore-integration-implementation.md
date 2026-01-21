# Swift ProxyCore Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire the macOS app to the embedded Go proxy core with manual start/stop, auto config apply, and default listeners (HTTP 12560, SOCKS5 12561) plus configurable control address.

**Architecture:** Add a Swift controller to manage the Go child process and control API, a settings store for control/listener config, and a config builder mapping SwiftData rules to Go config JSON. UI adds start/stop and status, and auto-applies config on changes.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, URLSession.

---

### Task 1: Extend Swift rule model (priority) and update rule UI

**Files:**
- Modify: `mac/ProxyMac/ProxyMac/Models/Rule.swift`
- Modify: `mac/ProxyMac/ProxyMac/Views/RuleDetailView.swift`
- Modify: `mac/ProxyMac/ProxyMac/Services/ImportExport.swift`
- Test: `mac/ProxyMac/ProxyMacTests/ImportExportTests.swift`

**Step 1: Write failing test**

Update `mac/ProxyMac/ProxyMacTests/ImportExportTests.swift` to assert priority round-trip:

```swift
func testExportImportIncludesPriority() throws {
    let rule = Rule(host: "api.dev.test", pathPrefix: "/", upstream: "http://localhost", enabled: true, note: nil, order: 0, priority: 7)
    let data = try RuleJSON.export([rule])
    let decoded = try RuleJSON.importRules(data)
    XCTAssertEqual(decoded.first?.priority, 7)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: FAIL (Rule has no priority).

**Step 3: Implement minimal changes**

Update `Rule.swift`:

```swift
var priority: Int = 0

init(..., order: Int = 0, priority: Int = 0) {
    ...
    self.priority = priority
}

enum CodingKeys: String, CodingKey {
    ...
    case priority
}

required convenience init(from decoder: Decoder) throws {
    ...
    let priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
    self.init(..., order: order, priority: priority)
}

func encode(to encoder: Encoder) throws {
    ...
    try container.encode(priority, forKey: .priority)
}
```

Update `RuleDetailView.swift` to add a simple priority field:

```swift
TextField("Priority", value: $rule.priority, formatter: NumberFormatter())
```

**Step 4: Run tests**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: PASS

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Models/Rule.swift mac/ProxyMac/ProxyMac/Views/RuleDetailView.swift mac/ProxyMac/ProxyMacTests/ImportExportTests.swift
git commit -m "feat: add rule priority support"
```

---

### Task 2: Add settings store for control address and listeners

**Files:**
- Create: `mac/ProxyMac/ProxyMac/Services/ProxySettings.swift`
- Test: `mac/ProxyMac/ProxyMacTests/ProxySettingsTests.swift`

**Step 1: Write failing tests**

Create `ProxySettingsTests.swift`:

```swift
import XCTest
@testable import ProxyMac

final class ProxySettingsTests: XCTestCase {
    func testDefaults() {
        let settings = ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        XCTAssertEqual(settings.controlAddress, "127.0.0.1:5959")
        XCTAssertEqual(settings.httpPort, 12560)
        XCTAssertEqual(settings.socksPort, 12561)
        XCTAssertTrue(settings.httpEnabled)
        XCTAssertTrue(settings.socksEnabled)
    }
}
```

**Step 2: Run tests to verify fail**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: FAIL (ProxySettings missing).

**Step 3: Implement minimal settings store**

Create `ProxySettings.swift`:

```swift
import Foundation

@MainActor
final class ProxySettings: ObservableObject {
    @Published var controlAddress: String { didSet { defaults.set(controlAddress, forKey: Keys.controlAddress) } }
    @Published var httpPort: Int { didSet { defaults.set(httpPort, forKey: Keys.httpPort) } }
    @Published var socksPort: Int { didSet { defaults.set(socksPort, forKey: Keys.socksPort) } }
    @Published var httpEnabled: Bool { didSet { defaults.set(httpEnabled, forKey: Keys.httpEnabled) } }
    @Published var socksEnabled: Bool { didSet { defaults.set(socksEnabled, forKey: Keys.socksEnabled) } }

    private let defaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        self.controlAddress = userDefaults.string(forKey: Keys.controlAddress) ?? "127.0.0.1:5959"
        self.httpPort = userDefaults.integer(forKey: Keys.httpPort)
        self.socksPort = userDefaults.integer(forKey: Keys.socksPort)
        self.httpEnabled = userDefaults.object(forKey: Keys.httpEnabled) as? Bool ?? true
        self.socksEnabled = userDefaults.object(forKey: Keys.socksEnabled) as? Bool ?? true

        if self.httpPort == 0 { self.httpPort = 12560 }
        if self.socksPort == 0 { self.socksPort = 12561 }
    }

    struct Snapshot: Equatable {
        let controlAddress: String
        let httpPort: Int
        let socksPort: Int
        let httpEnabled: Bool
        let socksEnabled: Bool
    }

    var snapshot: Snapshot {
        Snapshot(controlAddress: controlAddress, httpPort: httpPort, socksPort: socksPort, httpEnabled: httpEnabled, socksEnabled: socksEnabled)
    }

    private enum Keys {
        static let controlAddress = "proxy.controlAddress"
        static let httpPort = "proxy.httpPort"
        static let socksPort = "proxy.socksPort"
        static let httpEnabled = "proxy.httpEnabled"
        static let socksEnabled = "proxy.socksEnabled"
    }
}
```

**Step 4: Run tests**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: PASS

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Services/ProxySettings.swift mac/ProxyMac/ProxyMacTests/ProxySettingsTests.swift
git commit -m "feat: add proxy settings store"
```

---

### Task 3: Add config builder + control client apply

**Files:**
- Create: `mac/ProxyMac/ProxyMac/Services/ProxyConfigBuilder.swift`
- Modify: `mac/ProxyMac/ProxyMac/Services/ControlClient.swift`
- Test: `mac/ProxyMac/ProxyMacTests/ProxyConfigBuilderTests.swift`

**Step 1: Write failing tests**

Create `ProxyConfigBuilderTests.swift`:

```swift
import XCTest
@testable import ProxyMac

final class ProxyConfigBuilderTests: XCTestCase {
    func testBuildConfigEncodesListenersAndRules() throws {
        let settings = ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        settings.httpPort = 12560
        settings.socksPort = 12561
        settings.httpEnabled = true
        settings.socksEnabled = true

        let rule = Rule(host: "api.dev.test", pathPrefix: "/", upstream: "http://localhost:3000", enabled: true, note: "n", order: 0, priority: 3)

        let data = try ProxyConfigBuilder.build(rules: [rule], settings: settings)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let listeners = json?["listeners"] as? [[String: Any]]
        XCTAssertEqual(listeners?.count, 2)
        let rules = json?["rules"] as? [[String: Any]]
        XCTAssertEqual(rules?.first?["priority"] as? Int, 3)
        XCTAssertEqual(rules?.first?["notes"] as? String, "n")
    }
}
```

**Step 2: Run tests to verify fail**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: FAIL (ProxyConfigBuilder missing).

**Step 3: Implement builder + client**

Create `ProxyConfigBuilder.swift`:

```swift
import Foundation

struct ProxyConfigBuilder {
    struct Listener: Codable {
        let type: String
        let addr: String
    }

    struct RulePayload: Codable {
        let host: String
        let pathPrefix: String
        let upstream: String
        let enabled: Bool
        let priority: Int
        let notes: String?
    }

    struct Config: Codable {
        let rules: [RulePayload]
        let listeners: [Listener]
    }

    static func build(rules: [Rule], settings: ProxySettings) throws -> Data {
        let listeners = buildListeners(settings: settings)
        let payloadRules = rules.map { rule in
            RulePayload(host: rule.host, pathPrefix: rule.pathPrefix, upstream: rule.upstream, enabled: rule.enabled, priority: rule.priority, notes: rule.note)
        }
        let cfg = Config(rules: payloadRules, listeners: listeners)
        return try JSONEncoder().encode(cfg)
    }

    static func buildListeners(settings: ProxySettings) -> [Listener] {
        var result: [Listener] = []
        if settings.httpEnabled {
            result.append(Listener(type: "http", addr: "127.0.0.1:\(settings.httpPort)"))
        }
        if settings.socksEnabled {
            result.append(Listener(type: "socks5", addr: "127.0.0.1:\(settings.socksPort)"))
        }
        return result
    }
}
```

Update `ControlClient.swift` to add applyConfig:

```swift
func applyConfig(_ data: Data) async throws {
    var request = URLRequest(url: baseURL.appendingPathComponent("config"))
    request.httpMethod = "POST"
    request.httpBody = data
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let (_, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw NSError(domain: "ControlClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
    }
}

func health() async throws {
    let url = baseURL.appendingPathComponent("health")
    let (_, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw NSError(domain: "ControlClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
    }
}
```

**Step 4: Run tests**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: PASS

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Services/ProxyConfigBuilder.swift mac/ProxyMac/ProxyMac/Services/ControlClient.swift mac/ProxyMac/ProxyMacTests/ProxyConfigBuilderTests.swift
git commit -m "feat: add config builder and control apply"
```

---

### Task 4: Add ProxyCoreController (process lifecycle + auto apply)

**Files:**
- Create: `mac/ProxyMac/ProxyMac/Services/ProxyCoreController.swift`
- Test: `mac/ProxyMac/ProxyMacTests/ProxyCoreControllerTests.swift`

**Step 1: Write failing test**

Create a minimal test to validate state transitions with a fake ControlClient via protocol:

```swift
import XCTest
@testable import ProxyMac

final class ProxyCoreControllerTests: XCTestCase {
    func testStartsInStoppedState() {
        let controller = ProxyCoreController(controlClient: FakeControlClient())
        XCTAssertEqual(controller.state, .stopped)
    }
}
```

**Step 2: Run tests to verify fail**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: FAIL (ProxyCoreController missing).

**Step 3: Implement controller**

Create `ProxyCoreController.swift`:

```swift
import Foundation

@MainActor
final class ProxyCoreController: ObservableObject {
    enum State: Equatable {
        case stopped
        case starting
        case running
        case failed(String)
    }

    @Published private(set) var state: State = .stopped

    private var process: Process?
    private var pendingConfig: Data?
    private var controlClient: ControlClientProtocol

    init(controlClient: ControlClientProtocol = ControlClient()) {
        self.controlClient = controlClient
    }

    func start(controlAddress: String) {
        guard process == nil else { return }
        state = .starting

        guard let binaryURL = Bundle.main.url(forResource: "proxycore", withExtension: nil) else {
            state = .failed("proxycore not found")
            return
        }

        let proc = Process()
        proc.executableURL = binaryURL
        proc.arguments = ["-control", controlAddress]
        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.process = nil
                self?.state = .stopped
            }
        }

        do {
            try proc.run()
            process = proc
            Task { await waitForHealthThenApply() }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        state = .stopped
    }

    func updateControlAddress(_ address: String) {
        controlClient = ControlClient(baseURL: URL(string: "http://\(address)")!)
    }

    func applyConfig(_ data: Data) async {
        pendingConfig = data
        guard process != nil else { return }
        do {
            try await controlClient.applyConfig(data)
            state = .running
            pendingConfig = nil
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func waitForHealthThenApply() async {
        let maxAttempts = 20
        for _ in 0..<maxAttempts {
            do {
                try await controlClient.health()
                state = .running
                if let pendingConfig {
                    await applyConfig(pendingConfig)
                }
                return
            } catch {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
        state = .failed("health check timeout")
    }
}

protocol ControlClientProtocol {
    func health() async throws
    func applyConfig(_ data: Data) async throws
}

extension ControlClient: ControlClientProtocol {}

struct FakeControlClient: ControlClientProtocol {
    func health() async throws {}
    func applyConfig(_ data: Data) async throws {}
}
```

**Step 4: Run tests**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`

Expected: PASS

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMac/Services/ProxyCoreController.swift mac/ProxyMac/ProxyMacTests/ProxyCoreControllerTests.swift
git commit -m "feat: add proxy core controller"
```

---

### Task 5: Wire UI + config auto-apply + embed proxycore

**Files:**
- Modify: `mac/ProxyMac/ProxyMac/ProxyMacApp.swift`
- Modify: `mac/ProxyMac/ProxyMac/Views/RulesSplitView.swift`
- Modify: `mac/ProxyMac/ProxyMac/Views/MenuBar.swift`
- Modify: `mac/ProxyMac/ProxyMac/Views/MainWindow.swift`
- Modify: `mac/ProxyMac/ProxyMac.xcodeproj/project.pbxproj`
- Create: `mac/ProxyMac/ProxyMac/Views/ProxySettingsView.swift`

**Step 1: Write failing tests**

Add a minimal UI test to ensure controller is injected:

```swift
func testAppProvidesProxySettings() {
    let settings = ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
    XCTAssertEqual(settings.httpPort, 12560)
}
```

**Step 2: Implement UI wiring**

Update `ProxyMacApp.swift` to create and inject `ProxySettings` + `ProxyCoreController` using `.environmentObject`.

Update `RulesSplitView.swift`:
- Add toolbar Start/Stop buttons bound to controller
- Add `.onChange(of: rules)` to build config and call controller.applyConfig
- Add `.onChange(of: settings.snapshot)` to do the same

Create `ProxySettingsView.swift` with fields for control address, HTTP/SOCKS ports, and enable toggles.

Update `MenuBar.swift` to include Start/Stop and status.

Add Xcode build phase to compile Go and copy `proxycore` into app bundle resources:

```bash
set -euo pipefail
ROOT="${SRCROOT}/../.."
GO_BIN="/opt/homebrew/opt/go@1.24/bin/go"
if [ ! -x "$GO_BIN" ]; then
  GO_BIN="$(command -v go)"
fi
if [ -z "$GO_BIN" ]; then
  echo "Go not found" >&2
  exit 1
fi
cd "$ROOT"
"$GO_BIN" build -o "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/proxycore" ./cmd/proxycore
chmod +x "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/proxycore"
```

**Step 3: Run tests/build**

Run: `xcodebuild -project mac/ProxyMac/ProxyMac.xcodeproj -scheme ProxyMac -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`

Expected: build succeeds, `proxycore` embedded.

**Step 4: Commit**

```bash
git add mac/ProxyMac/ProxyMac/ProxyMacApp.swift mac/ProxyMac/ProxyMac/Views/RulesSplitView.swift mac/ProxyMac/ProxyMac/Views/MenuBar.swift mac/ProxyMac/ProxyMac/Views/MainWindow.swift mac/ProxyMac/ProxyMac/Views/ProxySettingsView.swift mac/ProxyMac/ProxyMac.xcodeproj/project.pbxproj
git commit -m "feat: wire proxy core into app"
```

---

### Task 6: Local integration verification

**Steps:**
1) Build the Go core: ` /opt/homebrew/opt/go@1.24/bin/go build -o /tmp/proxycore ./cmd/proxycore`
2) Start: `/tmp/proxycore -control 127.0.0.1:5959`
3) Apply config:

```bash
cat > /tmp/proxy.json <<'JSON'
{"listeners":[{"type":"http","addr":"127.0.0.1:12560"},{"type":"socks5","addr":"127.0.0.1:12561"}],"rules":[{"host":"api.dev.test","pathPrefix":"/","upstream":"http://127.0.0.1:3001","enabled":true,"priority":1}]}
JSON
curl -X POST -H 'Content-Type: application/json' --data @/tmp/proxy.json http://127.0.0.1:5959/config
```

4) Start a local upstream: `python3 -m http.server 3001`
5) HTTP proxy: `curl -x http://127.0.0.1:12560 http://api.dev.test/`
6) SOCKS5 proxy: `curl --socks5-hostname 127.0.0.1:12561 http://api.dev.test/`

---

## Notes
- Keep loopback-only listeners.
- Control address change requires restart.
- UI polish deferred.
