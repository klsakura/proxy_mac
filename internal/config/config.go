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
