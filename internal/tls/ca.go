package tls

import (
    "crypto/rand"
    "crypto/rsa"
    "crypto/tls"
    "crypto/x509"
    "crypto/x509/pkix"
    "math/big"
    "time"
)

type CA struct {
    Cert *x509.Certificate
    Key  *rsa.PrivateKey
}

func NewCA(commonName string) (*CA, error) {
    key, err := rsa.GenerateKey(rand.Reader, 2048)
    if err != nil {
        return nil, err
    }
    tmpl := &x509.Certificate{
        SerialNumber: big.NewInt(1),
        Subject:      pkix.Name{CommonName: commonName},
        NotBefore:    time.Now().Add(-time.Hour),
        NotAfter:     time.Now().Add(365 * 24 * time.Hour),
        KeyUsage:     x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
        IsCA:         true,
        BasicConstraintsValid: true,
    }
    der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
    if err != nil {
        return nil, err
    }
    cert, err := x509.ParseCertificate(der)
    if err != nil {
        return nil, err
    }
    return &CA{Cert: cert, Key: key}, nil
}

func (c *CA) Issue(host string, ttl time.Duration) (*tls.Certificate, error) {
    key, err := rsa.GenerateKey(rand.Reader, 2048)
    if err != nil {
        return nil, err
    }
    tmpl := &x509.Certificate{
        SerialNumber: big.NewInt(time.Now().UnixNano()),
        Subject:      pkix.Name{CommonName: host},
        DNSNames:     []string{host},
        NotBefore:    time.Now().Add(-time.Hour),
        NotAfter:     time.Now().Add(ttl),
        KeyUsage:     x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment,
        ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
    }
    der, err := x509.CreateCertificate(rand.Reader, tmpl, c.Cert, &key.PublicKey, c.Key)
    if err != nil {
        return nil, err
    }
    leaf, err := x509.ParseCertificate(der)
    if err != nil {
        return nil, err
    }
    cert := &tls.Certificate{
        Certificate: [][]byte{der, c.Cert.Raw},
        PrivateKey:  key,
        Leaf:        leaf,
    }
    return cert, nil
}
