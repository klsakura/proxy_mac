package dns

import "testing"

func TestResolveDevDomain(t *testing.T) {
    srv := NewServer("dev.test")
    ip, ok := srv.Resolve("api.dev.test")
    if !ok || ip != "127.0.0.1" {
        t.Fatalf("unexpected resolve: %v ok=%v", ip, ok)
    }
}
