# ProxyMac Core Proxy - Design

Date: 2026-01-20

## Goal
Build a macOS native app for local development proxying without Docker/Nginx or system proxy changes. The app provides UI-configured rules and runs a local proxy that developers point their tools to.

## Key Decisions
- Platform: macOS 14+.
- Architecture: SwiftUI app + Go proxy core (child process) with local IPC.
- No Network Extension; no automatic system proxy changes.
- TLS: HTTPS CONNECT pass-through only (no MITM).
- Protocols: HTTP and SOCKS5.
- Listeners: multiple loopback-only listeners (127.0.0.1 / ::1).
- Rules: UI-configured with priority + specificity matching; HTTPS matches host:port only; HTTP can use path prefix.
- Default behavior: unmatched traffic is direct (transparent) to the original target.

## Architecture
1) **SwiftUI App**: rule editor, status, import/export, validation. Persists rules using SwiftData. Manages lifecycle of the Go core process.
2) **Go Proxy Core**: implements HTTP proxy, HTTPS CONNECT tunneling, SOCKS5 proxy, rule matching, and forwarding. Exposes a local control API over Unix Domain Socket (preferred) or localhost HTTP for configuration updates and status.
3) **IPC Contract**: Swift sends rule sets and listener configs; Go responds with health/status, errors, and active listener info. Hot reload without restarting the process.

## Data Flow
Client sets proxy to a local listener -> Go core parses protocol -> rule match -> forward to upstream or direct -> return response. Swift UI updates rules -> IPC -> Go core hot-reloads in-memory rules.

## Rules
- Fields: id, enabled, priority, host, pathPrefix, upstream, notes.
- Host supports exact and wildcard (e.g., *.example.com). Path prefix applies only to HTTP requests.
- Matching: filter enabled; sort by priority, then by specificity (exact host over wildcard; longer path prefix wins).
- Action: forward to upstream URL. No block/deny rule in v1.

## Error Handling
- Configuration validation in UI: invalid URLs, port conflicts, or non-loopback listeners rejected before save.
- Go core: HTTP parse errors -> 400; upstream failures -> 502; CONNECT failure -> tunnel error + close.
- UI shows running/stopped state, last error, and provides restart control for core process.
- Logging: minimal operational logs by default; optional debug toggle without persistent request bodies.

## Testing
- Go unit tests: rule matching, priority/specificity ordering, HTTP/CONNECT/SOCKS5 handshake and forwarding.
- Integration tests: local upstream service to verify routing and failure cases.
- Swift tests: rule CRUD, validation, import/export.
- Manual: browser proxy settings, rule hit/miss, port conflicts, core restart.

## Out of Scope (v1)
- TLS MITM, certificate management, or transparent proxying.
- System-wide proxy configuration.
- Request/response body rewriting or traffic capture.
- Authentication for SOCKS5.

## Open Questions
- Exact IPC schema and versioning strategy.
- Rule import conflict resolution policy (by id vs. by content).
