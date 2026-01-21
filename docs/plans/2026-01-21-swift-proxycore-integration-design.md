# ProxyMac Swift Integration - Design

Date: 2026-01-21

## Goal
Integrate the Go proxy core into the macOS app. The app embeds the `proxycore` binary, manually starts/stops it, and auto-pushes config updates when rules or settings change. Default listeners are HTTP 12560 and SOCKS5 12561. Control API default is 127.0.0.1:5959 and is configurable.

## Key Decisions
- Delivery: Embed `proxycore` in the app bundle.
- Lifecycle: Manual start/stop from UI; no auto-start.
- Updates: Rule/listener changes auto-apply via control API.
- Control: HTTP control API on configurable loopback address.
- Listeners: Multiple listeners, loopback-only; defaults HTTP 12560 and SOCKS5 12561.
- HTTPS: CONNECT pass-through only; host matching only for HTTPS.

## Architecture
1) **ProxyCoreController** (Swift): manages `Process` lifecycle, health polling, and config apply. Tracks state (stopped/starting/running/failed) and last error.
2) **ProxyConfigBuilder** (Swift): maps SwiftData rules + settings into Go config JSON (rules + listeners). Validates loopback and port range before sending.
3) **ControlClient** (Swift): HTTP client for `/health` and `/config`.
4) **Settings** (Swift): stores control address and listener ports; defaults to 127.0.0.1:5959, 12560, 12561.

## Data Flow
- User clicks Start -> Controller launches embedded `proxycore` with `-control`.
- Controller polls `/health` until ready -> sends config with rules + listeners.
- When rules/settings change -> auto-send updated config via `/config`.
- Stop -> terminate child process, update status.

## Error Handling
- Start failure or health timeout -> UI shows error and offers retry.
- Config validation errors -> block send and surface message in UI.
- Control errors -> keep app state, show "Not connected" status.

## Testing & Local Verification
- Swift unit tests for config mapping and validation.
- Manual local verification: Start core, apply config, curl via HTTP proxy and SOCKS5 proxy to local upstream.

## Out of Scope
- UI polishing.
- System proxy automation.
