# Rules UI Design

Date: 2026-01-20

## Goal
Add a rules configuration UI in the macOS app: list + detail editor, import/export, and global sort mode (Auto/Manual) with drag-reorder in manual mode.

## Layout
- `NavigationSplitView` with sidebar list and detail editor.
- Sidebar row shows: enabled toggle, host, pathPrefix, upstream summary.
- Detail editor includes: host, pathPrefix, upstream, enabled, note.
- Toolbar actions: Add, Delete, Import, Export, Sort Mode (Auto/Manual).

## Data Model
Extend `Rule` model with:
- `enabled: Bool`
- `note: String?`
- `order: Int`

Sort mode stored in `@AppStorage` (UserDefaults). No new tables required.

## Sorting Behavior
- **Auto**: list is sorted by computed priority (host specificity, then longer pathPrefix, then host lexicographic). The stored `order` is ignored.
- **Manual**: list is sorted by `order` and supports drag-and-drop; reorder updates `order` persistently.

## Import/Export
- Export: serialize all rules via `RuleJSON.export`.
- Import: append decoded rules and assign `order` after current max.
- Parsing errors show a non-blocking alert.

## Validation
Inline validation in detail editor:
- `host` non-empty
- `pathPrefix` starts with `/`
- `upstream` must be valid URL

## Error Handling
- Failed import shows an alert with error text.
- Invalid fields show inline warnings; save is blocked only if critical fields are empty.

## Testing
- Unit tests for sort order (auto vs manual) and import/export merge behavior.
- UI tests are optional for v1.

