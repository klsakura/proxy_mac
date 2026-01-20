package main

import (
    "flag"
    "log"
    "net/http"
    "os"

    "github.com/klsakura/proxy_mac/internal/config"
    "github.com/klsakura/proxy_mac/internal/control"
    "github.com/klsakura/proxy_mac/internal/server"
)

func main() {
    configPath := flag.String("config", "", "config json path")
    controlAddr := flag.String("control", "127.0.0.1:5959", "control addr")
    flag.Parse()

    mgr := server.NewManager()

    if *configPath != "" {
        f, err := os.Open(*configPath)
        if err != nil {
            log.Fatalf("open config: %v", err)
        }
        defer f.Close()
        cfg, err := config.Parse(f)
        if err != nil {
            log.Fatalf("parse config: %v", err)
        }
        if err := mgr.ApplyConfig(cfg); err != nil {
            log.Fatalf("apply config: %v", err)
        }
    }

    h := control.NewHandler(mgr)
    log.Printf("control listening on %s", *controlAddr)
    if err := http.ListenAndServe(*controlAddr, h); err != nil {
        log.Fatalf("control server: %v", err)
    }
}
