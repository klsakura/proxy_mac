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
