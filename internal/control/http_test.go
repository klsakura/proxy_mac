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
