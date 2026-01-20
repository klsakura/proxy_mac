package proxy

import (
    "net/http"
    "net/http/httputil"
    "net/url"

    "github.com/klsakura/proxy_mac/internal/rules"
)

type HeaderRules struct {
    Add map[string]string
}

type handler struct {
    rules  []rules.Rule
    header HeaderRules
}

func NewHandler(rules []rules.Rule, header HeaderRules) http.Handler {
    return &handler{rules: rules, header: header}
}

func (h *handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    rule, ok := rules.Match(h.rules, r.Host, r.URL.Path)
    if !ok {
        http.Error(w, "no matching rule", http.StatusBadGateway)
        return
    }

    target, err := url.Parse(rule.Upstream)
    if err != nil {
        http.Error(w, "bad upstream", http.StatusBadGateway)
        return
    }

    proxy := httputil.NewSingleHostReverseProxy(target)
    proxy.Director = func(req *http.Request) {
        req.URL.Scheme = target.Scheme
        req.URL.Host = target.Host
        req.Host = target.Host
        for k, v := range h.header.Add {
            req.Header.Set(k, v)
        }
    }
    proxy.ServeHTTP(w, r)
}
