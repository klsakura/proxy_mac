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
