package config

import (
    "encoding/json"
    "io"

    "github.com/klsakura/proxy_mac/internal/rules"
)

type Config struct {
    Rules []rules.Rule `json:"rules"`
}

func Parse(r io.Reader) (Config, error) {
    var cfg Config
    dec := json.NewDecoder(r)
    err := dec.Decode(&cfg)
    return cfg, err
}
