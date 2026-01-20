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
