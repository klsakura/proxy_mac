# Proxy Core Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the Go proxy core (HTTP + HTTPS CONNECT + SOCKS5) with rule matching, multi loopback listeners, and a control API for hot config reload.

**Architecture:** The Go core runs as a child process. It exposes a local control HTTP API and serves multiple local listeners (HTTP proxy and SOCKS5). Rules are stored in memory and can be hot-reloaded via the control API. HTTPS is CONNECT pass-through (no MITM).

**Tech Stack:** Go 1.24, net/http, net, encoding/json.

---

### Task 1: Update rule model + matching (priority + specificity)

**Files:**
- Modify: `internal/rules/rules.go`
- Modify: `internal/rules/rules_test.go`
- Create: `internal/rules/store.go`

**Step 1: Write the failing tests**

Add/replace tests in `internal/rules/rules_test.go`:

```go
package rules

import "testing"

func TestMatchHTTP_PriorityAndSpecificity(t *testing.T) {
    rules := []Rule{
        {Host: "*.dev.test", PathPrefix: "/", Upstream: "http://wild", Enabled: true, Priority: 1},
        {Host: "api.dev.test", PathPrefix: "/v1/", Upstream: "http://specific", Enabled: true, Priority: 1},
        {Host: "api.dev.test", PathPrefix: "/v1/admin", Upstream: "http://admin", Enabled: true, Priority: 1},
        {Host: "api.dev.test", PathPrefix: "/v1/", Upstream: "http://prio", Enabled: true, Priority: 5},
        {Host: "api.dev.test", PathPrefix: "/v1/", Upstream: "http://disabled", Enabled: false, Priority: 10},
    }

    got, ok := MatchHTTP(rules, "api.dev.test", "/v1/users")
    if !ok || got.Upstream != "http://prio" {
        t.Fatalf("expected priority rule, got=%v ok=%v", got, ok)
    }

    got, ok = MatchHTTP(rules, "api.dev.test", "/v1/admin/settings")
    if !ok || got.Upstream != "http://admin" {
        t.Fatalf("expected most specific path, got=%v ok=%v", got, ok)
    }
}

func TestMatchHost_IgnoresPath(t *testing.T) {
    rules := []Rule{
        {Host: "*.dev.test", PathPrefix: "/", Upstream: "http://wild", Enabled: true, Priority: 1},
        {Host: "api.dev.test", PathPrefix: "/v1/", Upstream: "http://api", Enabled: true, Priority: 1},
    }

    got, ok := MatchHost(rules, "api.dev.test")
    if !ok || got.Upstream != "http://api" {
        t.Fatalf("expected host match, got=%v ok=%v", got, ok)
    }
}

func TestStoreSnapshotReplace(t *testing.T) {
    store := NewStore([]Rule{{Host: "a", Upstream: "http://a", Enabled: true}})
    if len(store.Snapshot()) != 1 {
        t.Fatalf("expected 1 rule")
    }
    store.Replace([]Rule{{Host: "b", Upstream: "http://b", Enabled: true}})
    if got := store.Snapshot()[0].Host; got != "b" {
        t.Fatalf("expected replace to update rules, got %q", got)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `go test ./internal/rules -v`

Expected: FAIL (missing MatchHTTP/MatchHost, fields).

**Step 3: Write minimal implementation**

Update `internal/rules/rules.go` and create `internal/rules/store.go`:

```go
package rules

import "strings"

type Rule struct {
    ID         string `json:"id"`
    Enabled    bool   `json:"enabled"`
    Priority   int    `json:"priority"`
    Host       string `json:"host"`
    PathPrefix string `json:"pathPrefix"`
    Upstream   string `json:"upstream"`
    Notes      string `json:"notes"`
}

func MatchHTTP(rules []Rule, host, path string) (Rule, bool) {
    return match(rules, host, path, true)
}

func MatchHost(rules []Rule, host string) (Rule, bool) {
    return match(rules, host, "", false)
}

func match(rules []Rule, host, path string, usePath bool) (Rule, bool) {
    var best Rule
    found := false
    bestPriority := -1
    bestHost := -1
    bestPath := -1

    for _, r := range rules {
        if !r.Enabled {
            continue
        }
        hostScore, ok := matchHostScore(r.Host, host)
        if !ok {
            continue
        }
        if usePath && !strings.HasPrefix(path, r.PathPrefix) {
            continue
        }
        pathScore := 0
        if usePath {
            pathScore = len(r.PathPrefix)
        }
        if !found || compare(r.Priority, hostScore, pathScore, bestPriority, bestHost, bestPath) {
            best = r
            bestPriority = r.Priority
            bestHost = hostScore
            bestPath = pathScore
            found = true
        }
    }

    return best, found
}

func compare(p, h, pa, bp, bh, bpa int) bool {
    if p != bp {
        return p > bp
    }
    if h != bh {
        return h > bh
    }
    return pa > bpa
}

func matchHostScore(pattern, host string) (int, bool) {
    if strings.EqualFold(pattern, host) {
        return 10000 + len(pattern), true
    }
    if strings.HasPrefix(pattern, "*.") {
        suffix := strings.TrimPrefix(pattern, "*.")
        if strings.HasSuffix(strings.ToLower(host), "."+strings.ToLower(suffix)) {
            return len(suffix), true
        }
    }
    return 0, false
}
```

Create `internal/rules/store.go`:

```go
package rules

import "sync"

type Store struct {
    mu    sync.RWMutex
    rules []Rule
}

func NewStore(rules []Rule) *Store {
    return &Store{rules: rules}
}

func (s *Store) Snapshot() []Rule {
    s.mu.RLock()
    defer s.mu.RUnlock()
    out := make([]Rule, len(s.rules))
    copy(out, s.rules)
    return out
}

func (s *Store) Replace(rules []Rule) {
    s.mu.Lock()
    defer s.mu.Unlock()
    s.rules = rules
}
```

**Step 4: Run test to verify it passes**

Run: `go test ./internal/rules -v`

Expected: PASS

**Step 5: Commit**

```bash
git add internal/rules/rules.go internal/rules/store.go internal/rules/rules_test.go
git commit -m "feat: add rule priority matching"
```

---

### Task 2: Config + listener definitions and validation

**Files:**
- Modify: `internal/config/config.go`
- Modify: `internal/config/config_test.go`

**Step 1: Write the failing tests**

Update `internal/config/config_test.go`:

```go
package config

import (
    "strings"
    "testing"
)

const sample = `{"rules":[{"host":"api.dev.test","pathPrefix":"/v1/","upstream":"https://api.example.com","enabled":true,"priority":1}],"listeners":[{"type":"http","addr":"127.0.0.1:8080"},{"type":"socks5","addr":"127.0.0.1:1080"}]}`

func TestParseConfig(t *testing.T) {
    cfg, err := Parse(strings.NewReader(sample))
    if err != nil {
        t.Fatalf("parse failed: %v", err)
    }
    if len(cfg.Listeners) != 2 {
        t.Fatalf("unexpected listeners: %+v", cfg.Listeners)
    }
}

func TestValidateRejectsNonLoopback(t *testing.T) {
    cfg := Config{Listeners: []Listener{{Type: "http", Addr: "0.0.0.0:8080"}}}
    if err := cfg.Validate(); err == nil {
        t.Fatalf("expected non-loopback to fail")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `go test ./internal/config -v`

Expected: FAIL (missing Listener, Validate).

**Step 3: Write minimal implementation**

Update `internal/config/config.go`:

```go
package config

import (
    "encoding/json"
    "errors"
    "io"
    "net"
    "net/url"

    "github.com/klsakura/proxy_mac/internal/rules"
)

type Listener struct {
    Type string `json:"type"`
    Addr string `json:"addr"`
}

type Config struct {
    Rules     []rules.Rule `json:"rules"`
    Listeners []Listener   `json:"listeners"`
}

func Parse(r io.Reader) (Config, error) {
    var cfg Config
    dec := json.NewDecoder(r)
    err := dec.Decode(&cfg)
    return cfg, err
}

func (c Config) Validate() error {
    for _, l := range c.Listeners {
        if l.Type != "http" && l.Type != "socks5" {
            return errors.New("invalid listener type")
        }
        host, _, err := net.SplitHostPort(l.Addr)
        if err != nil {
            return err
        }
        if !isLoopback(host) {
            return errors.New("listener must be loopback")
        }
    }
    for _, r := range c.Rules {
        if r.Upstream == "" {
            return errors.New("rule upstream required")
        }
        if _, err := url.Parse(r.Upstream); err != nil {
            return err
        }
    }
    return nil
}

func isLoopback(host string) bool {
    if host == "localhost" {
        return true
    }
    ip := net.ParseIP(host)
    return ip != nil && ip.IsLoopback()
}
```

**Step 4: Run test to verify it passes**

Run: `go test ./internal/config -v`

Expected: PASS

**Step 5: Commit**

```bash
git add internal/config/config.go internal/config/config_test.go
git commit -m "feat: add listener config validation"
```

---

### Task 3: HTTP proxy + CONNECT tunneling

**Files:**
- Modify: `internal/proxy/proxy.go`
- Modify: `internal/proxy/proxy_test.go`

**Step 1: Write the failing tests**

Update `internal/proxy/proxy_test.go`:

```go
package proxy

import (
    "bufio"
    "fmt"
    "io"
    "net"
    "net/http"
    "net/http/httptest"
    "strings"
    "testing"

    "github.com/klsakura/proxy_mac/internal/rules"
)

func TestHTTPProxy_UpstreamMatch(t *testing.T) {
    upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    }))
    defer upstream.Close()

    store := rules.NewStore([]rules.Rule{{Host: "api.dev.test", PathPrefix: "/", Upstream: upstream.URL, Enabled: true}})
    h := NewHandler(store)

    req := httptest.NewRequest(http.MethodGet, "http://api.dev.test/", nil)
    rr := httptest.NewRecorder()
    h.ServeHTTP(rr, req)

    if rr.Code != http.StatusOK {
        t.Fatalf("unexpected status: %d", rr.Code)
    }
}

func TestHTTPProxy_DirectFallback(t *testing.T) {
    target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusTeapot)
    }))
    defer target.Close()

    store := rules.NewStore(nil)
    h := NewHandler(store)

    req := httptest.NewRequest(http.MethodGet, target.URL+"/", nil)
    rr := httptest.NewRecorder()
    h.ServeHTTP(rr, req)

    if rr.Code != http.StatusTeapot {
        t.Fatalf("unexpected status: %d", rr.Code)
    }
}

func TestCONNECTTunnel(t *testing.T) {
    echoLn, err := net.Listen("tcp", "127.0.0.1:0")
    if err != nil {
        t.Fatalf("listen: %v", err)
    }
    defer echoLn.Close()

    go func() {
        conn, _ := echoLn.Accept()
        if conn == nil {
            return
        }
        defer conn.Close()
        io.Copy(conn, conn)
    }()

    store := rules.NewStore(nil)
    h := NewHandler(store)
    proxy := httptest.NewServer(h)
    defer proxy.Close()

    conn, err := net.Dial("tcp", proxy.Listener.Addr().String())
    if err != nil {
        t.Fatalf("dial proxy: %v", err)
    }
    defer conn.Close()

    target := echoLn.Addr().String()
    fmt.Fprintf(conn, "CONNECT %s HTTP/1.1\r\nHost: %s\r\n\r\n", target, target)
    br := bufio.NewReader(conn)
    line, _ := br.ReadString('\n')
    if !strings.HasPrefix(line, "HTTP/1.1 200") {
        t.Fatalf("unexpected response: %q", line)
    }

    _, _ = br.ReadString('\n')

    if _, err := conn.Write([]byte("ping")); err != nil {
        t.Fatalf("write: %v", err)
    }
    buf := make([]byte, 4)
    if _, err := io.ReadFull(conn, buf); err != nil {
        t.Fatalf("read: %v", err)
    }
    if string(buf) != "ping" {
        t.Fatalf("unexpected echo: %q", string(buf))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `go test ./internal/proxy -v`

Expected: FAIL (NewHandler signature, CONNECT not implemented).

**Step 3: Write minimal implementation**

Update `internal/proxy/proxy.go` to use rule store and handle CONNECT:

```go
package proxy

import (
    "io"
    "net"
    "net/http"
    "net/url"
    "strings"

    "github.com/klsakura/proxy_mac/internal/rules"
)

type handler struct {
    store     *rules.Store
    transport *http.Transport
}

func NewHandler(store *rules.Store) http.Handler {
    return &handler{
        store: store,
        transport: &http.Transport{
            Proxy: nil,
        },
    }
}

func (h *handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    if r.Method == http.MethodConnect {
        h.handleConnect(w, r)
        return
    }
    h.handleHTTP(w, r)
}

func (h *handler) handleHTTP(w http.ResponseWriter, r *http.Request) {
    ruleset := h.store.Snapshot()
    rule, ok := rules.MatchHTTP(ruleset, r.Host, r.URL.Path)

    targetURL := r.URL
    if ok {
        if u, err := url.Parse(rule.Upstream); err == nil {
            targetURL = u
            targetURL.Path = r.URL.Path
            targetURL.RawQuery = r.URL.RawQuery
        }
    }
    if targetURL.Scheme == "" {
        targetURL.Scheme = "http"
    }
    if targetURL.Host == "" {
        targetURL.Host = r.Host
    }

    req := r.Clone(r.Context())
    req.URL = targetURL
    req.Host = targetURL.Host
    req.RequestURI = ""
    removeHopHeaders(req.Header)

    resp, err := h.transport.RoundTrip(req)
    if err != nil {
        http.Error(w, "bad gateway", http.StatusBadGateway)
        return
    }
    defer resp.Body.Close()

    copyHeader(w.Header(), resp.Header)
    w.WriteHeader(resp.StatusCode)
    io.Copy(w, resp.Body)
}

func (h *handler) handleConnect(w http.ResponseWriter, r *http.Request) {
    targetHost := r.Host
    ruleset := h.store.Snapshot()
    if rule, ok := rules.MatchHost(ruleset, hostOnly(targetHost)); ok {
        if u, err := url.Parse(rule.Upstream); err == nil {
            targetHost = hostPort(u)
        }
    }

    upstream, err := net.Dial("tcp", targetHost)
    if err != nil {
        http.Error(w, "connect failed", http.StatusBadGateway)
        return
    }

    hj, ok := w.(http.Hijacker)
    if !ok {
        http.Error(w, "hijack not supported", http.StatusInternalServerError)
        upstream.Close()
        return
    }
    client, _, err := hj.Hijack()
    if err != nil {
        http.Error(w, "hijack failed", http.StatusInternalServerError)
        upstream.Close()
        return
    }

    _, _ = client.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))

    go io.Copy(upstream, client)
    go io.Copy(client, upstream)
}

func hostOnly(hostport string) string {
    host := hostport
    if strings.Contains(hostport, ":") {
        if h, _, err := net.SplitHostPort(hostport); err == nil {
            host = h
        }
    }
    return host
}

func hostPort(u *url.URL) string {
    host := u.Host
    if !strings.Contains(host, ":") {
        if u.Scheme == "https" {
            host = host + ":443"
        } else {
            host = host + ":80"
        }
    }
    return host
}

func removeHopHeaders(h http.Header) {
    for _, k := range []string{"Proxy-Connection", "Connection", "Keep-Alive", "Proxy-Authenticate", "Proxy-Authorization", "Te", "Trailers", "Transfer-Encoding", "Upgrade"} {
        h.Del(k)
    }
}

func copyHeader(dst, src http.Header) {
    for k, v := range src {
        for _, vv := range v {
            dst.Add(k, vv)
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `go test ./internal/proxy -v`

Expected: PASS

**Step 5: Commit**

```bash
git add internal/proxy/proxy.go internal/proxy/proxy_test.go
git commit -m "feat: add http proxy and connect tunnel"
```

---

### Task 4: SOCKS5 server with rule-based upstream

**Files:**
- Create: `internal/socks5/server.go`
- Create: `internal/socks5/server_test.go`

**Step 1: Write the failing tests**

Create `internal/socks5/server_test.go`:

```go
package socks5

import (
    "encoding/binary"
    "io"
    "net"
    "testing"

    "github.com/klsakura/proxy_mac/internal/rules"
)

func TestSOCKS5ConnectWithRule(t *testing.T) {
    echoLn, err := net.Listen("tcp", "127.0.0.1:0")
    if err != nil {
        t.Fatalf("listen: %v", err)
    }
    defer echoLn.Close()

    go func() {
        conn, _ := echoLn.Accept()
        if conn == nil {
            return
        }
        defer conn.Close()
        io.Copy(conn, conn)
    }()

    store := rules.NewStore([]rules.Rule{{Host: "api.dev.test", Upstream: "http://" + echoLn.Addr().String(), Enabled: true}})
    srv := NewServer(store)

    ln, err := net.Listen("tcp", "127.0.0.1:0")
    if err != nil {
        t.Fatalf("listen: %v", err)
    }
    defer ln.Close()

    go srv.Serve(ln)

    conn, err := net.Dial("tcp", ln.Addr().String())
    if err != nil {
        t.Fatalf("dial socks: %v", err)
    }
    defer conn.Close()

    // greeting: version 5, 1 method, no-auth (0x00)
    conn.Write([]byte{0x05, 0x01, 0x00})
    resp := make([]byte, 2)
    io.ReadFull(conn, resp)
    if resp[1] != 0x00 {
        t.Fatalf("expected no-auth accepted")
    }

    // connect request to api.dev.test:443
    host := []byte("api.dev.test")
    req := []byte{0x05, 0x01, 0x00, 0x03, byte(len(host))}
    req = append(req, host...)
    port := make([]byte, 2)
    binary.BigEndian.PutUint16(port, 443)
    req = append(req, port...)
    conn.Write(req)

    // reply
    reply := make([]byte, 10)
    io.ReadFull(conn, reply)
    if reply[1] != 0x00 {
        t.Fatalf("expected success reply")
    }

    // tunnel data
    conn.Write([]byte("ping"))
    buf := make([]byte, 4)
    io.ReadFull(conn, buf)
    if string(buf) != "ping" {
        t.Fatalf("unexpected echo: %q", string(buf))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `go test ./internal/socks5 -v`

Expected: FAIL (package does not exist).

**Step 3: Write minimal implementation**

Create `internal/socks5/server.go`:

```go
package socks5

import (
    "encoding/binary"
    "io"
    "net"
    "net/url"
    "strconv"
    "strings"

    "github.com/klsakura/proxy_mac/internal/rules"
)

type Server struct {
    store *rules.Store
}

func NewServer(store *rules.Store) *Server {
    return &Server{store: store}
}

func (s *Server) Serve(ln net.Listener) error {
    for {
        conn, err := ln.Accept()
        if err != nil {
            return err
        }
        go s.handleConn(conn)
    }
}

func (s *Server) handleConn(conn net.Conn) {
    defer conn.Close()

    buf := make([]byte, 2)
    if _, err := io.ReadFull(conn, buf); err != nil {
        return
    }
    if buf[0] != 0x05 {
        return
    }
    nMethods := int(buf[1])
    methods := make([]byte, nMethods)
    if _, err := io.ReadFull(conn, methods); err != nil {
        return
    }
    conn.Write([]byte{0x05, 0x00})

    header := make([]byte, 4)
    if _, err := io.ReadFull(conn, header); err != nil {
        return
    }
    if header[0] != 0x05 || header[1] != 0x01 {
        return
    }

    dest, err := readAddr(conn, header[3])
    if err != nil {
        return
    }

    hostOnly := dest
    if h, _, err := net.SplitHostPort(dest); err == nil {
        hostOnly = h
    }
    dialAddr := dest
    if rule, ok := rules.MatchHost(s.store.Snapshot(), hostOnly); ok {
        if u, err := url.Parse(rule.Upstream); err == nil {
            dialAddr = hostPort(u)
        }
    }

    upstream, err := net.Dial("tcp", dialAddr)
    if err != nil {
        conn.Write([]byte{0x05, 0x01, 0x00, 0x01, 0, 0, 0, 0, 0, 0})
        return
    }
    defer upstream.Close()

    conn.Write([]byte{0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0})
    go io.Copy(upstream, conn)
    io.Copy(conn, upstream)
}

func readAddr(r io.Reader, atyp byte) (string, error) {
    switch atyp {
    case 0x01:
        ip := make([]byte, 4)
        if _, err := io.ReadFull(r, ip); err != nil {
            return "", err
        }
        port := make([]byte, 2)
        if _, err := io.ReadFull(r, port); err != nil {
            return "", err
        }
        return net.JoinHostPort(net.IP(ip).String(), portString(port)), nil
    case 0x03:
        lenb := make([]byte, 1)
        if _, err := io.ReadFull(r, lenb); err != nil {
            return "", err
        }
        host := make([]byte, int(lenb[0]))
        if _, err := io.ReadFull(r, host); err != nil {
            return "", err
        }
        port := make([]byte, 2)
        if _, err := io.ReadFull(r, port); err != nil {
            return "", err
        }
        return net.JoinHostPort(string(host), portString(port)), nil
    case 0x04:
        ip := make([]byte, 16)
        if _, err := io.ReadFull(r, ip); err != nil {
            return "", err
        }
        port := make([]byte, 2)
        if _, err := io.ReadFull(r, port); err != nil {
            return "", err
        }
        return net.JoinHostPort(net.IP(ip).String(), portString(port)), nil
    default:
        return "", io.ErrUnexpectedEOF
    }
}

func portString(b []byte) string {
    return strconv.Itoa(int(binary.BigEndian.Uint16(b)))
}

func hostPort(u *url.URL) string {
    host := u.Host
    if !strings.Contains(host, ":") {
        if u.Scheme == "https" {
            host = host + ":443"
        } else {
            host = host + ":80"
        }
    }
    return host
}
```

**Step 4: Run test to verify it passes**

Run: `go test ./internal/socks5 -v`

Expected: PASS

**Step 5: Commit**

```bash
git add internal/socks5/server.go internal/socks5/server_test.go
git commit -m "feat: add socks5 server"
```

---

### Task 5: Listener manager + control API + main wiring

**Files:**
- Modify: `internal/server/server.go`
- Modify: `internal/server/server_test.go`
- Modify: `internal/control/http.go`
- Modify: `internal/control/http_test.go`
- Modify: `cmd/proxycore/main.go`

**Step 1: Write failing tests**

Update `internal/control/http_test.go`:

```go
package control

import (
    "bytes"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/klsakura/proxy_mac/internal/config"
)

type fakeApplier struct{ applied bool }

func (f *fakeApplier) ApplyConfig(cfg config.Config) error {
    f.applied = true
    return nil
}

func TestHealthEndpoint(t *testing.T) {
    h := NewHandler(&fakeApplier{})
    rr := httptest.NewRecorder()
    req := httptest.NewRequest(http.MethodGet, "/health", nil)
    h.ServeHTTP(rr, req)
    if rr.Code != http.StatusOK {
        t.Fatalf("unexpected status: %d", rr.Code)
    }
}

func TestConfigApply(t *testing.T) {
    applier := &fakeApplier{}
    h := NewHandler(applier)
    body := []byte(`{"listeners":[{"type":"http","addr":"127.0.0.1:8080"}]}`)
    rr := httptest.NewRecorder()
    req := httptest.NewRequest(http.MethodPost, "/config", bytes.NewReader(body))
    h.ServeHTTP(rr, req)
    if rr.Code != http.StatusOK || !applier.applied {
        t.Fatalf("expected apply to be called")
    }
}
```

Update `internal/server/server_test.go`:

```go
package server

import (
    "net"
    "testing"

    "github.com/klsakura/proxy_mac/internal/config"
    "github.com/klsakura/proxy_mac/internal/rules"
)

func TestApplyConfigStartsHTTPListener(t *testing.T) {
    mgr := NewManager()
    cfg := config.Config{
        Rules:     []rules.Rule{{Host: "api.dev.test", PathPrefix: "/", Upstream: "http://example.com", Enabled: true}},
        Listeners: []config.Listener{{Type: "http", Addr: "127.0.0.1:0"}},
    }
    if err := mgr.ApplyConfig(cfg); err != nil {
        t.Fatalf("apply: %v", err)
    }
    defer mgr.Close()

    addrs := mgr.ActiveListeners()
    if len(addrs) == 0 {
        t.Fatalf("expected active listener")
    }

    conn, err := net.Dial("tcp", addrs[0].Addr)
    if err != nil {
        t.Fatalf("dial: %v", err)
    }
    conn.Close()
}
```

**Step 2: Run tests to verify they fail**

Run: `go test ./internal/control ./internal/server -v`

Expected: FAIL (new APIs missing).

**Step 3: Write minimal implementation**

Update `internal/control/http.go`:

```go
package control

import (
    "encoding/json"
    "net/http"

    "github.com/klsakura/proxy_mac/internal/config"
)

type Applier interface {
    ApplyConfig(cfg config.Config) error
}

type handler struct{
    applier Applier
}

func NewHandler(applier Applier) http.Handler {
    return &handler{applier: applier}
}

func (h *handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    switch r.URL.Path {
    case "/health":
        w.WriteHeader(http.StatusOK)
        return
    case "/config":
        if r.Method != http.MethodPost {
            http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
            return
        }
        var cfg config.Config
        if err := json.NewDecoder(r.Body).Decode(&cfg); err != nil {
            http.Error(w, "bad config", http.StatusBadRequest)
            return
        }
        if err := cfg.Validate(); err != nil {
            http.Error(w, err.Error(), http.StatusBadRequest)
            return
        }
        if err := h.applier.ApplyConfig(cfg); err != nil {
            http.Error(w, "apply failed", http.StatusBadGateway)
            return
        }
        w.WriteHeader(http.StatusOK)
        return
    default:
        http.NotFound(w, r)
    }
}
```

Update `internal/server/server.go` to manage listeners:

```go
package server

import (
    "net"
    "net/http"
    "sync"

    "github.com/klsakura/proxy_mac/internal/config"
    "github.com/klsakura/proxy_mac/internal/proxy"
    "github.com/klsakura/proxy_mac/internal/rules"
    "github.com/klsakura/proxy_mac/internal/socks5"
)

type ListenerState struct {
    Type string
    Addr string
}

type listenerHandle struct {
    typ string
    ln  net.Listener
}

type Manager struct {
    mu        sync.Mutex
    store     *rules.Store
    listeners map[string]listenerHandle
}

func NewManager() *Manager {
    return &Manager{store: rules.NewStore(nil), listeners: map[string]listenerHandle{}}
}

func (m *Manager) ApplyConfig(cfg config.Config) error {
    if err := cfg.Validate(); err != nil {
        return err
    }
    m.mu.Lock()
    defer m.mu.Unlock()

    m.store.Replace(cfg.Rules)

    for _, h := range m.listeners {
        h.ln.Close()
    }
    m.listeners = map[string]listenerHandle{}

    for _, l := range cfg.Listeners {
        ln, err := net.Listen("tcp", l.Addr)
        if err != nil {
            return err
        }
        key := l.Type + ":" + ln.Addr().String()
        m.listeners[key] = listenerHandle{typ: l.Type, ln: ln}
        switch l.Type {
        case "http":
            h := proxy.NewHandler(m.store)
            srv := &http.Server{Handler: h}
            go srv.Serve(ln)
        case "socks5":
            srv := socks5.NewServer(m.store)
            go srv.Serve(ln)
        }
    }

    return nil
}

func (m *Manager) ActiveListeners() []ListenerState {
    m.mu.Lock()
    defer m.mu.Unlock()
    out := make([]ListenerState, 0, len(m.listeners))
    for _, h := range m.listeners {
        out = append(out, ListenerState{Type: h.typ, Addr: h.ln.Addr().String()})
    }
    return out
}

func (m *Manager) Close() {
    m.mu.Lock()
    defer m.mu.Unlock()
    for _, h := range m.listeners {
        h.ln.Close()
    }
    m.listeners = map[string]listenerHandle{}
}
```

Update `cmd/proxycore/main.go`:

```go
package main

import (
    "flag"
    "log"
    "net/http"
    "os"

    "github.com/klsakura/proxy_mac/internal/config"
    "github.com/klsakura/proxy_mac/internal/control"
    "github.com/klsakura/proxy_mac/internal/server"
)

func main() {
    configPath := flag.String("config", "", "config json path")
    controlAddr := flag.String("control", "127.0.0.1:5959", "control addr")
    flag.Parse()

    mgr := server.NewManager()

    if *configPath != "" {
        f, err := os.Open(*configPath)
        if err != nil {
            log.Fatalf("open config: %v", err)
        }
        defer f.Close()
        cfg, err := config.Parse(f)
        if err != nil {
            log.Fatalf("parse config: %v", err)
        }
        if err := mgr.ApplyConfig(cfg); err != nil {
            log.Fatalf("apply config: %v", err)
        }
    }

    h := control.NewHandler(mgr)
    log.Printf("control listening on %s", *controlAddr)
    if err := http.ListenAndServe(*controlAddr, h); err != nil {
        log.Fatalf("control server: %v", err)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `go test ./internal/control ./internal/server -v`

Expected: PASS

Then run full suite:

Run: `go test ./...`

Expected: PASS

**Step 5: Commit**

```bash
git add internal/control/http.go internal/control/http_test.go internal/server/server.go internal/server/server_test.go cmd/proxycore/main.go
git commit -m "feat: add control api and listener manager"
```

---

## Notes
- Keep listeners loopback-only.
- HTTPS CONNECT uses host-only rule matching.
- SOCKS5 supports only no-auth and CONNECT (no UDP, no BIND).
- UI integration is deferred; the control API will be used later by Swift.
