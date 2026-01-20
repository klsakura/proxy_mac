package tls

import (
    "crypto/x509"
    "testing"
    "time"
)

func TestIssueLeafCert(t *testing.T) {
    ca, err := NewCA("ProxyMac Dev CA")
    if err != nil {
        t.Fatalf("new CA failed: %v", err)
    }

    cert, err := ca.Issue("api.dev.test", time.Hour)
    if err != nil {
        t.Fatalf("issue failed: %v", err)
    }

    pool := x509.NewCertPool()
    pool.AddCert(ca.Cert)

    opts := x509.VerifyOptions{
        DNSName: "api.dev.test",
        Roots:   pool,
    }
    if _, err := cert.Leaf.Verify(opts); err != nil {
        t.Fatalf("verify failed: %v", err)
    }
}
