package rules

import "strings"

type Rule struct {
    Host       string
    PathPrefix string
    Upstream   string
}

func Match(rules []Rule, host, path string) (Rule, bool) {
    for _, r := range rules {
        if matchHost(r.Host, host) && strings.HasPrefix(path, r.PathPrefix) {
            return r, true
        }
    }
    return Rule{}, false
}

func matchHost(pattern, host string) bool {
    if pattern == host {
        return true
    }
    if strings.HasPrefix(pattern, "*.") {
        suffix := strings.TrimPrefix(pattern, "*.")
        return strings.HasSuffix(host, "."+suffix)
    }
    return false
}
