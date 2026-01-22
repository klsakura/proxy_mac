# Proxy Sidebar Design (Right Rail)

## Goal
Add a right-side status/actions rail (240-260pt) for proxy status, listener summary, and quick actions (Start/Stop, Apply, Health Check) in a "precision minimal" navy theme.

## Visual Direction
- Palette: navy primary, cool white surfaces, subtle blue-gray background gradient.
- Typography: Source Sans 3; numeric values use monospaced digits.
- Surfaces: card-based with thin border + soft shadow.
- Buttons: primary solid for Start/Stop, secondary outline for Apply and Health Check.

## Layout
Right rail sits beside the rule detail view:
1) **Status Card**: status dot + status text, and control address line.
2) **Listeners Card**: HTTP + SOCKS5 lines with port and enabled state.
3) **Actions Card**: Start/Stop (primary), Apply, Health Check (secondary).

Spacing: 12-16pt vertical rhythm, card padding ~16pt, corner radius 8-10.

## Behavior
- Status dot/text follow `ProxyCoreController.State`.
- Control address from `ProxySettings`.
- Listener summary from `ProxySettings` (ports + enabled flags).
- Apply triggers `ProxyCoreActions.applyConfig` using current rules/settings.
- Health Check calls control client health endpoint and updates state.

## Error Handling
- Failures show red status dot and "Proxy failed" text.
- If settings invalid, show a light warning line in status card and keep actions available.

## Testing
- Small unit test for status/label mapping and action wiring (reuse helpers if possible).
- No UI snapshot testing.

## Non-Goals
- No log stream, no advanced dashboards, no animations beyond color/state changes.
