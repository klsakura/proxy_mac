# Proxy Settings UI Polish Design (Brand: Navy + Minimal)

## Goal
Refine the macOS settings UI for the proxy tool with a "precision minimal" look, navy primary color, subtle blue-gray gradient background, and card-based layout. Keep behavior intact: settings persist locally, auto-apply to controller, and avoid heavy prompts.

## Visual Direction
- Palette: navy primary, cool white surface, subtle blue-gray gradient background.
- Typography: Source Sans 3 for all UI text; numeric fields use monospaced digits when possible.
- Surfaces: light card elevation with thin border; consistent spacing and restrained ornamentation.
- Controls: solid primary button where needed; default text fields + compact toggles; light helper text.

## Layout & Components
- **Settings view** as a two-card layout:
  1) **Control Address**: single text field with placeholder and hint.
  2) **Listeners**: two rows (HTTP / SOCKS5) with port field + enable toggle.
- **Status**: top small status dot + short label; right-side narrow column used for status/actions in main UI.
- **Field hints**: lightweight helper text under fields (e.g., port range, example).
- **Spacing**: 12–16pt vertical rhythm, compact for a tool-like feel.

## Data Flow
- `ProxySettings` remains source of truth (UserDefaults persistence).
- `RulesSplitView` observes rules signature and `settings.snapshot` to rebuild config and call controller apply.
- Settings UI does not require an explicit Apply button; state changes are auto-applied if proxy is running, otherwise stored and applied on start.

## Error Handling
- Validation is “soft”: inline red helper text for invalid ports or malformed control address.
- No modal alerts. Status column reflects "invalid config" when necessary.
- Default values appear as placeholders, not forced overwrites.

## Testing
- Unit tests for validation helpers (port range, address format).
- Existing behavior tests remain (config apply, settings defaults).
- No snapshot UI tests.

## Non-Goals
- No advanced theme system or full redesign of all screens.
- No heavy onboarding or modal flows.
