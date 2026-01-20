package dns

import "strings"

type Server struct {
    domain string
}

func NewServer(domain string) *Server {
    return &Server{domain: domain}
}

func (s *Server) Resolve(host string) (string, bool) {
    if host == s.domain || strings.HasSuffix(host, "."+s.domain) {
        return "127.0.0.1", true
    }
    return "", false
}
