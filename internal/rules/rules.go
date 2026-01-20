package rules

import "strings"

type Rule struct {
    ID         string `json:"id"`
    Enabled    bool   `json:"enabled"`
    Priority   int    `json:"priority"`
    Host       string `json:"host"`
    PathPrefix string `json:"pathPrefix"`
    Upstream   string `json:"upstream"`
    Notes      string `json:"notes"`
}

func MatchHTTP(rules []Rule, host, path string) (Rule, bool) {
    return match(rules, host, path, true)
}

func MatchHost(rules []Rule, host string) (Rule, bool) {
    return match(rules, host, "", false)
}

func match(rules []Rule, host, path string, usePath bool) (Rule, bool) {
    var best Rule
    found := false
    bestPriority := -1
    bestHost := -1
    bestPath := -1

    for _, r := range rules {
        if !r.Enabled {
            continue
        }
        hostScore, ok := matchHostScore(r.Host, host)
        if !ok {
            continue
        }
        if usePath && !strings.HasPrefix(path, r.PathPrefix) {
            continue
        }
        pathScore := 0
        if usePath {
            pathScore = len(r.PathPrefix)
        }
        if !found || compare(r.Priority, hostScore, pathScore, bestPriority, bestHost, bestPath) {
            best = r
            bestPriority = r.Priority
            bestHost = hostScore
            bestPath = pathScore
            found = true
        }
    }

    return best, found
}

func compare(p, h, pa, bp, bh, bpa int) bool {
    if p != bp {
        return p > bp
    }
    if h != bh {
        return h > bh
    }
    return pa > bpa
}

func matchHostScore(pattern, host string) (int, bool) {
    if strings.EqualFold(pattern, host) {
        return 10000 + len(pattern), true
    }
    if strings.HasPrefix(pattern, "*.") {
        suffix := strings.TrimPrefix(pattern, "*.")
        if strings.HasSuffix(strings.ToLower(host), "."+strings.ToLower(suffix)) {
            return len(suffix), true
        }
    }
    return 0, false
}
