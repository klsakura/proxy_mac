package control

import (
    "encoding/json"
    "net/http"

    "github.com/klsakura/proxy_mac/internal/config"
)

type Applier interface {
    ApplyConfig(cfg config.Config) error
}

type handler struct {
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
