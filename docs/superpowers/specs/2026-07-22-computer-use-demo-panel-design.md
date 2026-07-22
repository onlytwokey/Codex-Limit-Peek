# Computer Use Demo Panel Design

**Status:** Proposed for written review

**Date:** 2026-07-22

## Context

Codex Limit Peek is an `LSUIElement` menu-bar application. Its status item is
available through macOS Accessibility and exposes the label
`Codex Limit Peek`, the current quota value, and `AXPress`. The main quota
surface is different: it is a borderless, nonactivating `NSPanel`, so opening
it does not add a normal Accessibility window. The running process therefore
continues to report zero AX windows after the panel appears.

That boundary makes the production app a poor direct target for Computer Use.
Computer Use can address ordinary application windows, but it cannot establish
a stable view or element tree from this panel. Browser mockups are not product
evidence, full-screen capture can expose unrelated private content, and the
documentation renderer is deterministic but noninteractive.

The project needs a first-party demonstration entry point that presents the
real panel in a normal, addressable window without changing the installed
menu-bar experience.

## Goals

- Give Computer Use a named, activating macOS window that contains the real
  production quota panel.
- Reuse `StatusPanelView`, `ThemePanelComposition`, `QuotaStore`,
  `AppearanceStore`, `AppearanceResolver`, and `MoreOverlayPresenter`; do not
  build a second visual implementation.
- Provide deterministic fixed quota data for LOUD, BOLD, and FROST captures.
- Keep demonstration data, appearance changes, timers, notifications, speech,
  and refreshes isolated from the user's production state.
- Let the panel's Refresh and More controls remain real controls so interaction
  behavior can be inspected when Computer Use can see the corresponding
  surface.
- Establish one documented evidence chain for future panel design work.

## Non-goals

- No change to the production menu-bar item, panel placement, panel style,
  window level, dismissal rules, quota parsing, or refresh schedule.
- No replacement for the deterministic documentation renderer.
- No claim that the demo window proves status-item anchoring or Window Server
  placement in the production app.
- No full-screen capture automation.
- No second executable target or shared-library extraction in the first
  version.
- No gallery, settings dashboard, fixture editor, or persistent demo
  preferences.
- No direct HTTP request or credential access.

## Considered Approaches

### 1. Add an explicit demo-window launch mode to the existing app

Launch the existing app bundle with `--demo-panel` and let `AppDelegate` enter
a separate, deterministic startup path. This path creates a titled,
activating `NSPanel`, attaches the existing panel views and presenter, and
skips production status-item and refresh startup.

This is the approved direction. It reuses internal production types without a
package-level refactor and gives Computer Use the normal window it requires.

### 2. Add a second SwiftPM demo executable

A separate executable would give the demo a strong packaging boundary, but the
current UI types live inside the main executable target. Sharing them would
require a library extraction or source duplication. That is disproportionate
to the capture problem and is rejected for the first version.

### 3. Automate the production status item and capture the screen

Accessibility can reliably press the real status item, but the opened panel
still has no AX window. Coordinate clicks and full-screen capture would be
fragile and could include unrelated private content. This remains suitable
only for a final human-assisted smoke check and is rejected as the normal
audit path.

## Launch Contract

The app gains an internal launch configuration parser with these supported
arguments:

```text
--demo-panel
--demo-theme loud|bold|frost
--demo-layout dual|weekly
```

`--demo-panel` selects demo mode. The theme defaults to `loud` and the layout
defaults to `dual`. Unknown or missing option values cause a clear launch
error on standard error and terminate the demo process; they never fall through
into production startup.

Normal launches without `--demo-panel` follow the existing application path
unchanged.

A repository script, `scripts/run-demo-panel.sh`, runs `scripts/build-app.sh`
and opens a new instance of the resulting development app with the requested
arguments. It never reuses an unverified stale bundle. The script accepts only
the documented theme and layout values. It does not install or replace the
user's end-user application.

## Demo Data Contract

Demo mode constructs an isolated `QuotaStore` and `AppearanceStore`.

The initial dual-window snapshot uses stable semantic values:

- 5-hour remaining quota: `81%`
- 5-hour reset: 1 hour 34 minutes after demo launch
- weekly remaining quota: `49%`
- weekly reset: 5 days after demo launch
- source: `Codex 示例`
- refresh health: live

The weekly-only snapshot uses the same weekly percentage and reset date as the
primary window. Dates are derived once from the demo launch time so countdowns
remain internally consistent while a capture session is running.

The demo provider always returns the selected fixed snapshot. Refresh therefore
exercises the real refresh button and store path without contacting the Codex
app-server or reading local quota records.

Appearance profiles start from the source defaults for all three themes. Theme
selection is determined by the launch argument. The first version deliberately
does not load the user's customized production profile because deterministic
baseline comparison is the primary goal.

## Persistence and Privacy Boundary

Demo mode uses a process-local in-memory `UserDefaults` implementation shared
by the demo quota and appearance stores. It must not read from or write to
`.standard`.

Demo startup does not call the production `QuotaStore.start()` path. It does
not:

- start automatic refresh timers;
- request notification permission;
- schedule speech;
- read Codex SQLite or JSONL records;
- launch `codex app-server`;
- inspect authentication data; or
- persist appearance, quota, or failure-diagnostic values.

Closing the demo window terminates only the demo process. A separately running
installed Codex Limit Peek process is not stopped or modified.

## Window and View Composition

Demo mode sets the application activation policy to `.regular` and does not
create an `NSStatusItem`. It creates one `NSPanel` with a standard titled,
activating style and the accessibility title `Codex Limit Peek Demo`.

The content area is exactly `ThemePanelLayout.width` by
`ThemePanelLayout.height`. The title bar may be visually minimized, but the
window must retain a standard AX window role and stable title. The panel is
centered on the current screen and uses a normal window level.

The content controller hosts the production `StatusPanelView` with the isolated
stores and a real `MoreOverlayPresenter`. The presenter attaches to the demo
`NSPanel`, so Refresh, More, appearance navigation, Escape, and color-panel
wiring continue to use production code.

The demo window must not add labels, selectors, grid backgrounds, explanatory
copy, or other chrome inside the 360 by 220 content area. Theme and layout
changes require relaunch arguments in the first version. This keeps every
captured content pixel attributable to the production panel.

## Computer Use Workflow

The supported audit sequence is:

1. Launch one demo instance with an explicit theme and layout.
2. Address the app by the full development bundle path.
3. Require a window named `Codex Limit Peek Demo` before continuing.
4. Capture and inspect the main panel window.
5. Use its AX elements to press Refresh or More when the requested audit needs
   interaction.
6. After every action, obtain a fresh app state and screenshot.
7. Relaunch for another theme or layout rather than mutating hidden state.
8. Use the documentation renderer for multi-state atlases and the production
   menu-bar app only for a final placement and dismissal smoke check.

If Computer Use cannot retrieve the named demo window, the run fails closed.
It must not fall back to a browser recreation, guessed coordinates, or a
full-screen screenshot and then describe that result as a product audit.

The More overlay is accepted only if the fresh post-click screenshot contains
the real overlay and its controls are operable. If the production borderless
child panels remain unavailable to Computer Use, the first version still
qualifies for main-panel review, but the overlay must be reported as a named
capture limitation. Making the overlay itself addressable requires a separate
design rather than changing its production window style inside this scope.

## Source Boundaries

The intended implementation introduces focused demo-only types rather than
adding launch, fixture, and persistence logic directly to existing views:

- `DemoPanelLaunchConfiguration`: parses and validates launch arguments.
- `DemoPanelFixture`: owns the fixed snapshot and launch-relative dates.
- `DemoQuotaProvider`: returns only the selected fixed snapshot.
- `DemoInMemoryUserDefaults`: process-local persistence substitute.
- `DemoPanelCoordinator`: owns the demo stores, presenter, and activating
  panel.

`AppDelegate` may branch once at startup and delegate demo ownership to
`DemoPanelCoordinator`. Existing production methods and window creation remain
unchanged.

`QuotaStore` may gain narrowly scoped initializer parameters for an initial
snapshot and refresh health, both defaulting to the current production
behavior. No public API is required, and no demo-specific state mutation method
is added after initialization.

## Failure Handling

- Invalid demo arguments terminate with an explanatory message and create no
  status item or window.
- Failure to create isolated defaults or the demo window terminates the demo
  process and does not start production mode.
- Closing the demo window closes any More overlay and color panel first.
- A demo refresh always resolves to the same fixed live snapshot.
- If the installed production app is already running, the demo remains a
  separate process and never terminates it.
- If the local Swift compiler and macOS SDK do not match, implementation
  verification stops at the toolchain gate. That environment failure is not
  treated as evidence of a source regression.

## Verification

### Automated

- Launch-configuration tests cover defaults, every supported value, missing
  values, unknown values, and non-demo production launch.
- Store tests confirm that demo initialization uses the fixed snapshot and live
  health without touching standard defaults.
- Provider tests confirm every refresh returns the selected fixed snapshot.
- Coordinator tests confirm demo mode creates no status item and creates one
  titled, activating, accessibility-addressable panel with a 360 by 220 content
  area.
- Lifecycle tests confirm production startup retains the existing accessory
  activation policy and status-item behavior.
- Tests confirm demo appearance edits leave standard production preferences
  unchanged.
- Existing application, More-overlay, appearance, quota, and documentation
  tests remain unchanged and pass.

### Manual and Computer Use

For LOUD, BOLD, and FROST in dual-window mode:

1. Launch the demo with the corresponding argument.
2. Confirm Computer Use returns the `Codex Limit Peek Demo` window instead of
   timing out.
3. Inspect the screenshot for the exact 360 by 220 panel content.
4. Press Refresh and confirm the quota values remain deterministic.
5. Press More and record whether the production overlay is both visible and
   operable.

Repeat one capture in weekly-only mode. Then run one human-assisted production
smoke check for status-item AXPress, placement below the menu bar, internal
click dismissal, and true outside-click dismissal.

Before any code result is accepted, the Swift compiler and SDK versions must
match. Then run the focused demo tests, `scripts/test.sh`,
`scripts/validate-doc-images.sh`, and `scripts/test-install.sh` in that order.

## Acceptance Criteria

- Computer Use can identify and capture a window titled
  `Codex Limit Peek Demo` without a full-screen screenshot.
- The captured 360 by 220 content is rendered by production panel views and
  resolvers.
- The three themes and both supported layouts are launchable with deterministic
  fixed data.
- Demo mode performs no live quota read and writes no production preference.
- Normal app launch, menu-bar behavior, and installed-app state are unchanged.
- Main-panel audit limitations and More-overlay limitations are reported
  separately and truthfully.
