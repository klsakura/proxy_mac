package rules

import "testing"

func TestMatchDomainAndPath(t *testing.T) {
    rules := []Rule{
        {Host: "api.dev.test", PathPrefix: "/v1/", Upstream: "https://api.example.com"},
        {Host: "*.dev.test", PathPrefix: "/", Upstream: "https://default.example.com"},
    }

    got, ok := Match(rules, "api.dev.test", "/v1/users")
    if !ok || got.Upstream != "https://api.example.com" {
        t.Fatalf("expected v1 rule, got=%v ok=%v", got, ok)
    }

    got, ok = Match(rules, "assets.dev.test", "/img/logo.png")
    if !ok || got.Upstream != "https://default.example.com" {
        t.Fatalf("expected wildcard rule, got=%v ok=%v", got, ok)
    }
}
