package proxy

import (
    "io"
    "net"
    "net/http"
    "net/url"
    "strings"

    "github.com/klsakura/proxy_mac/internal/rules"
)

type handler struct {
    store     *rules.Store
    transport *http.Transport
}

func NewHandler(store *rules.Store) http.Handler {
    return &handler{
        store: store,
        transport: &http.Transport{
            Proxy: nil,
        },
    }
}

func (h *handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    if r.Method == http.MethodConnect {
        h.handleConnect(w, r)
        return
    }
    h.handleHTTP(w, r)
}

func (h *handler) handleHTTP(w http.ResponseWriter, r *http.Request) {
    ruleset := h.store.Snapshot()
    rule, ok := rules.MatchHTTP(ruleset, r.Host, r.URL.Path)

    targetURL := r.URL
    if ok {
        if u, err := url.Parse(rule.Upstream); err == nil {
            targetURL = u
            targetURL.Path = r.URL.Path
            targetURL.RawQuery = r.URL.RawQuery
        }
    }
    if targetURL.Scheme == "" {
        targetURL.Scheme = "http"
    }
    if targetURL.Host == "" {
        targetURL.Host = r.Host
    }

    req := r.Clone(r.Context())
    req.URL = targetURL
    req.Host = targetURL.Host
    req.RequestURI = ""
    removeHopHeaders(req.Header)

    resp, err := h.transport.RoundTrip(req)
    if err != nil {
        http.Error(w, "bad gateway", http.StatusBadGateway)
        return
    }
    defer resp.Body.Close()

    copyHeader(w.Header(), resp.Header)
    w.WriteHeader(resp.StatusCode)
    io.Copy(w, resp.Body)
}

func (h *handler) handleConnect(w http.ResponseWriter, r *http.Request) {
    targetHost := r.Host
    ruleset := h.store.Snapshot()
    if rule, ok := rules.MatchHost(ruleset, hostOnly(targetHost)); ok {
        if u, err := url.Parse(rule.Upstream); err == nil {
            targetHost = hostPort(u)
        }
    }

    upstream, err := net.Dial("tcp", targetHost)
    if err != nil {
        http.Error(w, "connect failed", http.StatusBadGateway)
        return
    }

    hj, ok := w.(http.Hijacker)
    if !ok {
        http.Error(w, "hijack not supported", http.StatusInternalServerError)
        upstream.Close()
        return
    }
    client, _, err := hj.Hijack()
    if err != nil {
        http.Error(w, "hijack failed", http.StatusInternalServerError)
        upstream.Close()
        return
    }

    _, _ = client.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))

    go io.Copy(upstream, client)
    go io.Copy(client, upstream)
}

func hostOnly(hostport string) string {
    host := hostport
    if strings.Contains(hostport, ":") {
        if h, _, err := net.SplitHostPort(hostport); err == nil {
            host = h
        }
    }
    return host
}

func hostPort(u *url.URL) string {
    host := u.Host
    if !strings.Contains(host, ":") {
        if u.Scheme == "https" {
            host = host + ":443"
        } else {
            host = host + ":80"
        }
    }
    return host
}

func removeHopHeaders(h http.Header) {
    for _, k := range []string{"Proxy-Connection", "Connection", "Keep-Alive", "Proxy-Authenticate", "Proxy-Authorization", "Te", "Trailers", "Transfer-Encoding", "Upgrade"} {
        h.Del(k)
    }
}

func copyHeader(dst, src http.Header) {
    for k, v := range src {
        for _, vv := range v {
            dst.Add(k, vv)
        }
    }
}
