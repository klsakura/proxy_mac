package config

import (
    "strings"
    "testing"
)

const sample = `{"rules":[{"host":"api.dev.test","pathPrefix":"/v1/","upstream":"https://api.example.com"}]}`

func TestParseConfig(t *testing.T) {
    cfg, err := Parse(strings.NewReader(sample))
    if err != nil {
        t.Fatalf("parse failed: %v", err)
    }
    if len(cfg.Rules) != 1 || cfg.Rules[0].Host != "api.dev.test" {
        t.Fatalf("unexpected rules: %+v", cfg.Rules)
    }
}
