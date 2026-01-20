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
