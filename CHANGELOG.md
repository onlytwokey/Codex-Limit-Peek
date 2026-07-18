# Changelog

## [Unreleased]

### Added
- Initial open-source hardening pass for project metadata.
- Added contribution and security docs (`CONTRIBUTING.md`, `SECURITY.md`).
- Added current quota reads through the local Codex app-server.
- Added automated tests for response parsing, process cleanup, cache restoration, and refresh-state behavior.
- Added a one-command source installer that builds in a temporary SwiftPM scratch directory, installs locally, verifies its ad-hoc signature, and removes build artifacts on exit.
- Added explicit MIT attribution for the upstream project and initial commit.
- Added independently remembered LOUD, BOLD, and FROST appearance themes for the panel and menu bar status item.
- Added real-time controls for theme colors, status colors, typography, outlines, corner radius, shadows, and opacity.
- Added a global 90%–150% font-size control for the appearance editor.
- Added a per-theme status-item display editor for font size, outline, corner radius, shadow depth and blur, horizontal padding, and tag height.
- Added square custom-color buttons backed by the macOS system color panel, including alpha selection.

### Changed
- Removed mock quota fallback so the app now prefers real local session-derived quotas.
- Menu bar now displays unavailable state when no quota record is available.
- Restores the last cached quota immediately at launch and refreshes automatically every five minutes.
- Accepts local SQLite and JSONL fallback records only when their source timestamp is no more than 15 minutes old.
- Keeps the last usable value after a refresh failure and marks the menu bar item with a static white/red stripe pattern.
- Reuses live quota snapshots younger than 60 seconds when opening the panel or requesting a voice update.
- Creates the status panel and speech synthesizer only when they are first needed.
- Coalesces repeated refresh requests behind a 10-second minimum provider-start interval while keeping the first launch refresh immediate.
- Supports a weekly-only Codex quota window and automatically restores the five-hour-plus-weekly layout when both windows are available.
- Confirms live quota failures with retries after 15 and 45 seconds before showing the failure pattern, then retries recovery at a capped five-minute interval.
- Records only a safe local failure category, timestamp, and count so refresh problems can be diagnosed without storing session content.
- Allows up to 12 seconds for a local app-server read so slower cold starts do not become false refresh failures.
- Limited JSONL fallback candidates to 20 files modified within 30 minutes and reduced each file-tail read to 256 KB.
- Documented separate end-user installation and incremental contributor build workflows.
- Replaced the system More popover with an arrowless, theme-resolved two-level overlay.
- Slider changes now show the saving state only after editing ends, then return to saved when persistence completes.
- Migrated appearance profiles to schema v3 while preserving supported legacy status-item geometry.
- Refreshed the GitHub interface preview with equal-weight LOUD, BOLD, and FROST status-item/panel renders plus a LOUD settings overview.

### Fixed
- Prevented clicks and trackpad scroll gestures inside the appearance overlay from passing through to underlying desktop content or dismissing the overlay.
- Kept custom color selection reliable across overlay navigation and placed the shared system color panel above the appearance window.

## [0.1.0] - 2026-07-09

- Initial release scaffold with 5-hour and weekly quota meter, menu bar status text, and popover panel.
- Local-only inference from `.codex/sessions` logs.
- Optional periodic voice broadcast and low-quota notifications.
