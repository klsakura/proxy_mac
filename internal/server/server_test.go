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
