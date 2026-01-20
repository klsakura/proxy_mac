# macOS Local Dev Proxy Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS local-dev proxy with a Go core (MITM + routing) and a Swift UI for rule management, plus scaffolding for Network Extension + privileged helper.

**Architecture:** Go core handles TLS MITM, routing, header rewrite, DNS; Swift UI manages rules (SwiftData), import/export, and controls the core via IPC; Network Extension + helper are scaffolded to enable system capture and privileged operations.

**Tech Stack:** Go 1.24, Swift/SwiftUI, SwiftData, Network Extension, SMJobBless, JSON config.

---

### Task 1: Initialize Go module + rules matcher

**Files:**
- Create: `go.mod`
- Create: `internal/rules/rules.go`
- Create: `internal/rules/rules_test.go`

**Step 1: Write the failing test**

```go
package rules

import "testing"

func TestMatchDomainAndPath(t *testing.T) {
    rules := []Rule{
        {Host: "api.dev.test", PathPrefix: "/v1/", Upstream: "https://api.example.com"},
        {Host: "*.dev.test", PathPrefix: "/", Upstream: "https://default.example.com"},
    }

    got, ok := Match(rules, "api.dev.test", "/v1/users")
    if !ok || got.Upstream != "https://api.example.com" {
        t.Fatalf("expected v1 rule, got=%v ok=%v", got, ok)
    }

    got, ok = Match(rules, "assets.dev.test", "/img/logo.png")
    if !ok || got.Upstream != "https://default.example.com" {
        t.Fatalf("expected wildcard rule, got=%v ok=%v", got, ok)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/rules -v`
Expected: FAIL with "undefined: Rule" / "undefined: Match"

**Step 3: Write minimal implementation**

```go
package rules

import "strings"

type Rule struct {
    Host       string
    PathPrefix string
    Upstream   string
}

func Match(rules []Rule, host, path string) (Rule, bool) {
    for _, r := range rules {
        if matchHost(r.Host, host) && strings.HasPrefix(path, r.PathPrefix) {
            return r, true
        }
    }
    return Rule{}, false
}

func matchHost(pattern, host string) bool {
    if pattern == host {
        return true
    }
    if strings.HasPrefix(pattern, "*.") {
        suffix := strings.TrimPrefix(pattern, "*.")
        return strings.HasSuffix(host, "."+suffix)
    }
    return false
}
```

Also create `go.mod`:

```go
module github.com/klsakura/proxy_mac

go 1.24
```

**Step 4: Run test to verify it passes**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/rules -v`
Expected: PASS

**Step 5: Commit**

```bash
git add go.mod internal/rules/rules.go internal/rules/rules_test.go
git commit -m "feat: add rule matcher"
```

---

### Task 2: JSON config load/save

**Files:**
- Create: `internal/config/config.go`
- Create: `internal/config/config_test.go`

**Step 1: Write the failing test**

```go
package config

import (
    "strings"
    "testing"
)

const sample = `{"rules":[{"host":"api.dev.test","pathPrefix":"/v1/","upstream":"https://api.example.com"}]}`

func TestParseConfig(t *testing.T) {
    cfg, err := Parse(strings.NewReader(sample))
    if err != nil {
        t.Fatalf("parse failed: %v", err)
    }
    if len(cfg.Rules) != 1 || cfg.Rules[0].Host != "api.dev.test" {
        t.Fatalf("unexpected rules: %+v", cfg.Rules)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/config -v`
Expected: FAIL with "undefined: Parse"

**Step 3: Write minimal implementation**

```go
package config

import (
    "encoding/json"
    "io"

    "github.com/klsakura/proxy_mac/internal/rules"
)

type Config struct {
    Rules []rules.Rule `json:"rules"`
}

func Parse(r io.Reader) (Config, error) {
    var cfg Config
    dec := json.NewDecoder(r)
    err := dec.Decode(&cfg)
    return cfg, err
}
```

**Step 4: Run test to verify it passes**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/config -v`
Expected: PASS

**Step 5: Commit**

```bash
git add internal/config/config.go internal/config/config_test.go
git commit -m "feat: add JSON config parsing"
```

---

### Task 3: HTTP reverse proxy + header rewrite

**Files:**
- Create: `internal/proxy/proxy.go`
- Create: `internal/proxy/proxy_test.go`

**Step 1: Write the failing test**

```go
package proxy

import (
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/klsakura/proxy_mac/internal/rules"
)

func TestHeaderRewrite(t *testing.T) {
    upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if r.Header.Get("X-Dev") != "1" {
            t.Fatalf("missing header rewrite")
        }
        w.WriteHeader(http.StatusOK)
    }))
    defer upstream.Close()

    rules := []rules.Rule{{Host: "api.dev.test", PathPrefix: "/", Upstream: upstream.URL}}
    h := NewHandler(rules, HeaderRules{Add: map[string]string{"X-Dev": "1"}})

    req := httptest.NewRequest(http.MethodGet, "http://api.dev.test/", nil)
    rr := httptest.NewRecorder()
    h.ServeHTTP(rr, req)

    if rr.Code != http.StatusOK {
        t.Fatalf("unexpected status: %d", rr.Code)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/proxy -v`
Expected: FAIL with "undefined: NewHandler"

**Step 3: Write minimal implementation**

```go
package proxy

import (
    "net/http"
    "net/http/httputil"
    "net/url"

    "github.com/klsakura/proxy_mac/internal/rules"
)

type HeaderRules struct {
    Add map[string]string
}

type handler struct {
    rules  []rules.Rule
    header HeaderRules
}

func NewHandler(rules []rules.Rule, header HeaderRules) http.Handler {
    return &handler{rules: rules, header: header}
}

func (h *handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    rule, ok := rules.Match(h.rules, r.Host, r.URL.Path)
    if !ok {
        http.Error(w, "no matching rule", http.StatusBadGateway)
        return
    }

    target, err := url.Parse(rule.Upstream)
    if err != nil {
        http.Error(w, "bad upstream", http.StatusBadGateway)
        return
    }

    proxy := httputil.NewSingleHostReverseProxy(target)
    proxy.ModifyResponse = func(resp *http.Response) error {
        return nil
    }
    proxy.Director = func(req *http.Request) {
        req.URL.Scheme = target.Scheme
        req.URL.Host = target.Host
        req.Host = target.Host
        for k, v := range h.header.Add {
            req.Header.Set(k, v)
        }
    }
    proxy.ServeHTTP(w, r)
}
```

**Step 4: Run test to verify it passes**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/proxy -v`
Expected: PASS

**Step 5: Commit**

```bash
git add internal/proxy/proxy.go internal/proxy/proxy_test.go
git commit -m "feat: add reverse proxy with header rewrite"
```

---

### Task 4: Root CA + leaf certificate generation

**Files:**
- Create: `internal/tls/ca.go`
- Create: `internal/tls/ca_test.go`

**Step 1: Write the failing test**

```go
package tls

import (
    "crypto/x509"
    "testing"
    "time"
)

func TestIssueLeafCert(t *testing.T) {
    ca, err := NewCA("ProxyMac Dev CA")
    if err != nil {
        t.Fatalf("new CA failed: %v", err)
    }

    cert, err := ca.Issue("api.dev.test", time.Hour)
    if err != nil {
        t.Fatalf("issue failed: %v", err)
    }

    pool := x509.NewCertPool()
    pool.AddCert(ca.Cert)

    opts := x509.VerifyOptions{
        DNSName: "api.dev.test",
        Roots:   pool,
    }
    if _, err := cert.Leaf.Verify(opts); err != nil {
        t.Fatalf("verify failed: %v", err)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/tls -v`
Expected: FAIL with "undefined: NewCA"

**Step 3: Write minimal implementation**

```go
package tls

import (
    "crypto/rand"
    "crypto/rsa"
    "crypto/x509"
    "crypto/x509/pkix"
    "math/big"
    "time"
)

type CA struct {
    Cert *x509.Certificate
    Key  *rsa.PrivateKey
}

func NewCA(commonName string) (*CA, error) {
    key, err := rsa.GenerateKey(rand.Reader, 2048)
    if err != nil {
        return nil, err
    }
    tmpl := &x509.Certificate{
        SerialNumber: big.NewInt(1),
        Subject:      pkix.Name{CommonName: commonName},
        NotBefore:    time.Now().Add(-time.Hour),
        NotAfter:     time.Now().Add(365 * 24 * time.Hour),
        KeyUsage:     x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
        IsCA:         true,
        BasicConstraintsValid: true,
    }
    der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
    if err != nil {
        return nil, err
    }
    cert, err := x509.ParseCertificate(der)
    if err != nil {
        return nil, err
    }
    return &CA{Cert: cert, Key: key}, nil
}

func (c *CA) Issue(host string, ttl time.Duration) (*x509.Certificate, error) {
    key, err := rsa.GenerateKey(rand.Reader, 2048)
    if err != nil {
        return nil, err
    }
    tmpl := &x509.Certificate{
        SerialNumber: big.NewInt(time.Now().UnixNano()),
        Subject:      pkix.Name{CommonName: host},
        DNSNames:     []string{host},
        NotBefore:    time.Now().Add(-time.Hour),
        NotAfter:     time.Now().Add(ttl),
        KeyUsage:     x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment,
        ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
    }
    der, err := x509.CreateCertificate(rand.Reader, tmpl, c.Cert, &key.PublicKey, c.Key)
    if err != nil {
        return nil, err
    }
    cert, err := x509.ParseCertificate(der)
    if err != nil {
        return nil, err
    }
    cert.Leaf = cert
    return cert, nil
}
```

**Step 4: Run test to verify it passes**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/tls -v`
Expected: PASS

**Step 5: Commit**

```bash
git add internal/tls/ca.go internal/tls/ca_test.go
git commit -m "feat: add root CA and leaf issuance"
```

---

### Task 5: Core HTTP proxy server (non-NE) for local dev

**Files:**
- Create: `cmd/proxycore/main.go`
- Create: `internal/server/server.go`
- Create: `internal/server/server_test.go`

**Step 1: Write the failing test**

```go
package server

import (
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/klsakura/proxy_mac/internal/rules"
)

func TestServerRoutes(t *testing.T) {
    upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    }))
    defer upstream.Close()

    srv := New(Config{
        Rules: []rules.Rule{{Host: "api.dev.test", PathPrefix: "/", Upstream: upstream.URL}},
    })

    req := httptest.NewRequest(http.MethodGet, "http://api.dev.test/", nil)
    rr := httptest.NewRecorder()
    srv.Handler().ServeHTTP(rr, req)

    if rr.Code != http.StatusOK {
        t.Fatalf("unexpected status: %d", rr.Code)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/server -v`
Expected: FAIL with "undefined: New"

**Step 3: Write minimal implementation**

```go
package server

import (
    "net/http"

    "github.com/klsakura/proxy_mac/internal/proxy"
    "github.com/klsakura/proxy_mac/internal/rules"
)

type Config struct {
    Rules []rules.Rule
}

type Server struct {
    handler http.Handler
}

func New(cfg Config) *Server {
    h := proxy.NewHandler(cfg.Rules, proxy.HeaderRules{Add: map[string]string{}})
    return &Server{handler: h}
}

func (s *Server) Handler() http.Handler {
    return s.handler
}
```

**Step 4: Run test to verify it passes**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/server -v`
Expected: PASS

**Step 5: Commit**

```bash
git add cmd/proxycore/main.go internal/server/server.go internal/server/server_test.go
git commit -m "feat: add proxy core server skeleton"
```

---

### Task 6: DNS server for dev.test

**Files:**
- Create: `internal/dns/server.go`
- Create: `internal/dns/server_test.go`

**Step 1: Write the failing test**

```go
package dns

import (
    "testing"
)

func TestResolveDevDomain(t *testing.T) {
    srv := NewServer("dev.test")
    ip, ok := srv.Resolve("api.dev.test")
    if !ok || ip != "127.0.0.1" {
        t.Fatalf("unexpected resolve: %v ok=%v", ip, ok)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/dns -v`
Expected: FAIL with "undefined: NewServer"

**Step 3: Write minimal implementation**

```go
package dns

import "strings"

type Server struct {
    domain string
}

func NewServer(domain string) *Server {
    return &Server{domain: domain}
}

func (s *Server) Resolve(host string) (string, bool) {
    if host == s.domain || strings.HasSuffix(host, "."+s.domain) {
        return "127.0.0.1", true
    }
    return "", false
}
```

**Step 4: Run test to verify it passes**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/dns -v`
Expected: PASS

**Step 5: Commit**

```bash
git add internal/dns/server.go internal/dns/server_test.go
git commit -m "feat: add dev domain dns resolver"
```

---

### Task 7: SwiftData rule model + JSON import/export

**Files:**
- Create: `mac/ProxyMac/Models/Rule.swift`
- Create: `mac/ProxyMac/Models/RuleStore.swift`
- Create: `mac/ProxyMac/Services/ImportExport.swift`
- Create: `mac/ProxyMacTests/ImportExportTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import ProxyMac

final class ImportExportTests: XCTestCase {
    func testExportImportRoundTrip() throws {
        let rules = [Rule(host: "api.dev.test", pathPrefix: "/v1/", upstream: "https://api.example.com")]
        let data = try RuleJSON.export(rules)
        let decoded = try RuleJSON.importRules(data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].host, "api.dev.test")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme ProxyMac -destination 'platform=macOS' test`
Expected: FAIL with "Cannot find type 'Rule' in scope"

**Step 3: Write minimal implementation**

```swift
import Foundation
import SwiftData

@Model
final class Rule: Codable {
    var host: String
    var pathPrefix: String
    var upstream: String

    init(host: String, pathPrefix: String, upstream: String) {
        self.host = host
        self.pathPrefix = pathPrefix
        self.upstream = upstream
    }
}

enum RuleJSON {
    static func export(_ rules: [Rule]) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(rules)
    }

    static func importRules(_ data: Data) throws -> [Rule] {
        let decoder = JSONDecoder()
        return try decoder.decode([Rule].self, from: data)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -scheme ProxyMac -destination 'platform=macOS' test`
Expected: PASS

**Step 5: Commit**

```bash
git add mac/ProxyMac/Models/Rule.swift mac/ProxyMac/Services/ImportExport.swift mac/ProxyMacTests/ImportExportTests.swift
git commit -m "feat: add SwiftData rule model and JSON import/export"
```

---

### Task 8: Swift UI shell (menu bar + main window)

**Files:**
- Create: `mac/ProxyMac/ProxyMacApp.swift`
- Create: `mac/ProxyMac/Views/MainWindow.swift`
- Create: `mac/ProxyMac/Views/MenuBar.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import ProxyMac

final class MenuBarTests: XCTestCase {
    func testMenuBarViewLoads() {
        _ = MenuBarView()
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme ProxyMac -destination 'platform=macOS' test`
Expected: FAIL with "Cannot find 'MenuBarView' in scope"

**Step 3: Write minimal implementation**

```swift
import SwiftUI

@main
struct ProxyMacApp: App {
    var body: some Scene {
        WindowGroup {
            MainWindow()
        }
        MenuBarExtra("ProxyMac") {
            MenuBarView()
        }
    }
}
```

```swift
import SwiftUI

struct MainWindow: View {
    var body: some View {
        Text("ProxyMac")
    }
}
```

```swift
import SwiftUI

struct MenuBarView: View {
    var body: some View {
        Button("Open") {}
        Divider()
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -scheme ProxyMac -destination 'platform=macOS' test`
Expected: PASS

**Step 5: Commit**

```bash
git add mac/ProxyMac/ProxyMacApp.swift mac/ProxyMac/Views/MainWindow.swift mac/ProxyMac/Views/MenuBar.swift mac/ProxyMacTests/MenuBarTests.swift
git commit -m "feat: add SwiftUI app shell"
```

---

### Task 9: Control plane API (Go core) + Swift client stub

**Files:**
- Create: `internal/control/http.go`
- Create: `internal/control/http_test.go`
- Create: `mac/ProxyMac/Services/ControlClient.swift`

**Step 1: Write the failing test**

```go
package control

import (
    "net/http"
    "net/http/httptest"
    "testing"
)

func TestHealthEndpoint(t *testing.T) {
    h := NewHandler()
    rr := httptest.NewRecorder()
    req := httptest.NewRequest(http.MethodGet, "/health", nil)
    h.ServeHTTP(rr, req)
    if rr.Code != http.StatusOK {
        t.Fatalf("unexpected status: %d", rr.Code)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/control -v`
Expected: FAIL with "undefined: NewHandler"

**Step 3: Write minimal implementation**

```go
package control

import "net/http"

type handler struct{}

func NewHandler() http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if r.URL.Path != "/health" {
            http.NotFound(w, r)
            return
        }
        w.WriteHeader(http.StatusOK)
    })
}
```

**Step 4: Run test to verify it passes**

Run: `GOTOOLCHAIN=go1.24 go test ./internal/control -v`
Expected: PASS

**Step 5: Commit**

```bash
git add internal/control/http.go internal/control/http_test.go mac/ProxyMac/Services/ControlClient.swift
git commit -m "feat: add control plane stub"
```

---

### Task 10: Network Extension + Helper scaffolding (Xcode targets)

**Files:**
- Create: `mac/ProxyMac/ProxyMac.xcodeproj` (via Xcode)
- Create: `mac/ProxyMacExtensions/TransparentProxyProvider.swift`
- Create: `mac/ProxyMacHelper/HelperMain.swift`

**Step 1: Create Xcode project and targets**

- In Xcode: New Project → App (macOS) → name `ProxyMac` → SwiftUI + SwiftData.
- Add Network Extension target (Transparent Proxy Provider).
- Add Helper Tool target (SMJobBless) with minimal main.

**Step 2: Add minimal provider and helper**

```swift
import NetworkExtension

final class TransparentProxyProvider: NETransparentProxyProvider {
    override func startProxy(options: [String : Any]? = nil) async throws {
        // TODO: connect to Go core
    }
    override func stopProxy(with reason: NEProviderStopReason) async {
        // TODO: cleanup
    }
}
```

```swift
import Foundation

@main
struct HelperMain {
    static func main() {
        // TODO: implement privileged commands
        RunLoop.main.run()
    }
}
```

**Step 3: Build to verify targets compile**

Run: `xcodebuild -scheme ProxyMac -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add mac/ProxyMac mac/ProxyMacExtensions mac/ProxyMacHelper
git commit -m "chore: scaffold app, extension, helper"
```

---

### Task 11: Manual test checklist

**Files:**
- Create: `docs/tests/manual-checklist.md`

**Step 1: Write checklist**

```markdown
# Manual Test Checklist
- Install root CA and trust it in Keychain
- Enable Network Extension in System Settings
- Configure dev.test resolver
- Proxy on/off from menu bar
- Verify curl https://api.dev.test routes to upstream
- Verify browser request routes to upstream
- Uninstall cleanup removes cert + resolver
```

**Step 2: Commit**

```bash
git add docs/tests/manual-checklist.md
git commit -m "docs: add manual test checklist"
```

---

## Notes
- Go toolchain: always run tests with `GOTOOLCHAIN=go1.24`.
- This plan scaffolds NE + helper; full functionality will follow in later tasks once IPC + privilege flows are implemented.

