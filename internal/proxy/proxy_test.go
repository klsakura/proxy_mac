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
