# Changelog

## [Unreleased]

### Added
- Initial open-source hardening pass for project metadata.
- Added contribution and security docs (`CONTRIBUTING.md`, `SECURITY.md`).
- Added current quota reads through the local Codex app-server.
- Added automated tests for response parsing, process cleanup, cache restoration, and refresh-state behavior.
- Added a one-command source installer that builds in a temporary SwiftPM scratch directory, installs locally, verifies its ad-hoc signature, and removes build artifacts on exit.
- Added explicit MIT attribution for the upstream project and initial commit.

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

## [0.1.0] - 2026-07-09

- Initial release scaffold with 5-hour and weekly quota meter, menu bar status text, and popover panel.
- Local-only inference from `.codex/sessions` logs.
- Optional periodic voice broadcast and low-quota notifications.
