package rules

import "testing"

func TestMatchHTTP_PriorityAndSpecificity(t *testing.T) {
    rules := []Rule{
        {Host: "*.dev.test", PathPrefix: "/", Upstream: "http://wild", Enabled: true, Priority: 1},
        {Host: "api.dev.test", PathPrefix: "/v1/", Upstream: "http://specific", Enabled: true, Priority: 1},
        {Host: "api.dev.test", PathPrefix: "/v1/admin", Upstream: "http://admin", Enabled: true, Priority: 5},
        {Host: "api.dev.test", PathPrefix: "/v1/", Upstream: "http://prio", Enabled: true, Priority: 5},
        {Host: "api.dev.test", PathPrefix: "/v1/", Upstream: "http://disabled", Enabled: false, Priority: 10},
    }

    got, ok := MatchHTTP(rules, "api.dev.test", "/v1/users")
    if !ok || got.Upstream != "http://prio" {
        t.Fatalf("expected priority rule, got=%v ok=%v", got, ok)
    }

    got, ok = MatchHTTP(rules, "api.dev.test", "/v1/admin/settings")
    if !ok || got.Upstream != "http://admin" {
        t.Fatalf("expected most specific path, got=%v ok=%v", got, ok)
    }
}

func TestMatchHost_IgnoresPath(t *testing.T) {
    rules := []Rule{
        {Host: "*.dev.test", PathPrefix: "/", Upstream: "http://wild", Enabled: true, Priority: 1},
        {Host: "api.dev.test", PathPrefix: "/v1/", Upstream: "http://api", Enabled: true, Priority: 1},
    }

    got, ok := MatchHost(rules, "api.dev.test")
    if !ok || got.Upstream != "http://api" {
        t.Fatalf("expected host match, got=%v ok=%v", got, ok)
    }
}

func TestStoreSnapshotReplace(t *testing.T) {
    store := NewStore([]Rule{{Host: "a", Upstream: "http://a", Enabled: true}})
    if len(store.Snapshot()) != 1 {
        t.Fatalf("expected 1 rule")
    }
    store.Replace([]Rule{{Host: "b", Upstream: "http://b", Enabled: true}})
    if got := store.Snapshot()[0].Host; got != "b" {
        t.Fatalf("expected replace to update rules, got %q", got)
    }
}
