# macOS Local Dev Proxy - Design

Date: 2026-01-20

## Goal
Build a macOS native app to proxy local development traffic without Docker/Nginx. The app provides a UI to configure domain/path routing rules, and a system-level proxy that captures GUI and CLI traffic for local dev domains.

## Key Decisions
- Platform: macOS 14+.
- Architecture: Swift UI app + Go proxy core + Network Extension (transparent proxy) + privileged helper.
- DNS: local resolver for `*.dev.test` via `/etc/resolver` + local DNS server.
- TLS: MITM with auto-generated root CA; guide user to trust in Keychain.
- Protocols: HTTP/1.1, HTTP/2, WebSocket.
- Rules: UI-configured, domain + path match, persisted with SwiftData; import/export JSON.
- Scope: route/forward and header rewrite only; no body rewrite and no request history store.

## Architecture
1) **Swift UI App** (menu bar + window): rule editor, status, certificate flow, system permission UX, import/export. Stores rules in SwiftData and pushes updates to proxy core.
2) **Network Extension** (Transparent Proxy Provider): captures system traffic, applies whitelist (dev domains) and forwards matches to proxy core; non-matching traffic is passed through.
3) **Go Proxy Core**: TLS MITM, routing, header rewrite, HTTP/2 + WS handling, hot-reload rules, connection pooling. Exposes local IPC endpoint (Unix socket preferred).
4) **Privileged Helper** (SMJobBless): writes `/etc/resolver/dev.test`, installs/removes root CA, manages extension lifecycle.
5) **Local DNS**: resolves `*.dev.test` to 127.0.0.1; forwards other domains to system DNS.

## Data Flow
Client -> DNS resolves `*.dev.test` to localhost -> Transparent Proxy captures -> Go core terminates TLS -> rule match -> forward to upstream -> response -> back to client.

## Error Handling & Safety
- If proxy core fails, extension should fail-open for non-dev domains; dev domain traffic returns explicit error.
- If root CA is not trusted, UI shows a clear guide and retry path.
- All privileged operations are explicit, auditable, and reversible (uninstall cleans resolver + cert).
- Only minimal runtime logs (timestamp, host, status); no persistent request bodies.

## Testing
- Go unit tests: rule matching, header rewrite, HTTP/2, WebSocket.
- Integration tests: MITM correctness and upstream routing.
- DNS tests: dev domain resolution and forwarding.
- Swift tests: SwiftData persistence + import/export.
- Manual checklist: install flow, permissions, proxy on/off, uninstall cleanup.

## Out of Scope (v1)
- Body rewrite or scripting.
- Traffic replay/har capture.
- TCP/UDP proxying beyond HTTP(S).

## Open Questions
- Exact rule schema for import/export JSON.
- Logging verbosity and redaction rules.
- UI layout details and onboarding flow.
