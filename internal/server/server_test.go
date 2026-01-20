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
