package rules

import "sync"

type Store struct {
    mu    sync.RWMutex
    rules []Rule
}

func NewStore(rules []Rule) *Store {
    return &Store{rules: rules}
}

func (s *Store) Snapshot() []Rule {
    s.mu.RLock()
    defer s.mu.RUnlock()
    out := make([]Rule, len(s.rules))
    copy(out, s.rules)
    return out
}

func (s *Store) Replace(rules []Rule) {
    s.mu.Lock()
    defer s.mu.Unlock()
    s.rules = rules
}
