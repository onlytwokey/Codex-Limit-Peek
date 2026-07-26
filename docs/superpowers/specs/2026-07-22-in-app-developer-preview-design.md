# In-App Developer Preview Design

**Status:** Approved direction A on 2026-07-22<br>
**Scope:** Codex Limit Peek developer-only preview and Computer Use entry<br>
**Supersedes:** the separate `Codex Limit Peek Demo.app` preview-host design

## Decision

Codex Limit Peek will use the common internal-debug-tools pattern:

- one SwiftPM application target;
- one app name, bundle identifier, and executable identity;
- a developer preview window compiled only into development builds;
- no separately identified Demo application;
- no developer entry or launch behavior in production Release builds.

The development and installed production builds share an identity and therefore
must not run concurrently. The developer workflow switches to the development
build for an inspection session and restores the installed production app when
that session ends.

## Goals

- Give humans and Computer Use a stable, standard macOS window for inspecting
  and operating the real panel UI.
- Keep the normal menu-bar behavior available inside the development build.
- Preview deterministic themes, layouts, quota states, and failure states
  without reading or mutating live user data.
- Provide a controlled `Current` / `Candidate` promotion workflow for future
  panel experiments.
- Keep the installed production app bundle untouched during preview sessions.
- Restore the installed production process after a developer session exits.

## Non-Goals

- No second product, app identity, bundle identifier, or installed Demo app.
- No permanent developer surface in Release builds.
- No browser recreation of the panel.
- No direct HTTP calls, credentials, prompt content, or session-content access.
- No general-purpose settings dashboard or fixture editor.
- No simultaneous production and development processes with the same bundle
  identifier.

## Considered Approaches

### A. Same target with development-only internal tools — selected

The main target receives a `DEVELOPER_TOOLS` compilation condition in Debug
configuration. The development build exposes a standard preview window while
the Release build compiles without the entry and coordinator.

This is the normal internal-debug-surface pattern and preserves one product
identity.

### B. Hidden developer tools in Release — rejected

This would allow the installed production process to remain running throughout
an audit, but it would ship preview code and hidden entry behavior to end users.
That is unnecessary for this project.

### C. Separately packaged Preview Host — rejected

This offers process-level coexistence, but creates a second app identity and was
the source of ambiguous Computer Use, Launch Services, and quit behavior. It is
not the requested workflow.

## Build Boundary

`Package.swift` defines `DEVELOPER_TOOLS` only for Debug builds. All developer
entry, preview-window ownership, candidate registrations, and preview launch
arguments are guarded by this condition.

Both build configurations package:

```text
App name: Codex Limit Peek
Bundle ID: io.github.onlytwokey.CodexLimitPeek.MenuBar
Executable: CodexLimitPeek
```

`scripts/build-app.sh` keeps Release as its default and accepts a narrowly
validated `debug` configuration for developer tooling. It never creates
`Codex Limit Peek Demo.app`.

Release builds do not recognize `--developer-preview`, do not show a developer
action, and do not construct preview stores or windows.

## Developer Entry

Development builds expose two routes to the same coordinator:

1. A `开发者预览` action in the existing More actions surface for human use.
2. A `--developer-preview` launch argument that opens the window immediately
   for deterministic automation.

Opening the developer window from More leaves the development menu-bar process
running when the window closes. A process launched specifically with
`--developer-preview` exits when the preview window closes so the switching
script can restore the installed production app.

Repeated entry reuses and raises the existing preview window rather than
creating duplicates.

## Preview Window

The developer surface is a standard, titled, activating `NSWindow` with the
stable accessibility title `Codex Limit Peek Developer Preview`.

The window contains:

- a compact scenario bar for theme, layout, quota state, and implementation;
- one interactive 1:1 panel stage using the real production panel composition;
- `Current` and `Candidate` implementation choices;
- the real Refresh and More interactions;
- a concise indication that all displayed values are fixtures.

The stage preserves the production panel dimensions and shadow safety inset.
Developer controls sit outside the product surface so screenshots can clearly
distinguish the product panel from tooling chrome.

Only one implementation is interactive at a time. Switching between `Current`
and `Candidate` replaces the staged panel, avoiding duplicate More presenters
or competing auxiliary windows.

## Preview State Model

The initial scenario set is intentionally finite:

- healthy dual-window quota;
- weekly-only quota;
- warning quota;
- danger quota;
- unavailable quota;
- confirmed refresh failure with a usable stale snapshot.

Themes are `LOUD`, `BOLD`, and `FROST`. Scenario selection constructs a fresh
in-memory environment so every state is deterministic and independent.

The preview environment:

- uses an in-memory `UserDefaults` implementation;
- uses fixed `QuotaProvider` results;
- disables notifications, permission requests, speech, and recurring timers;
- does not launch `codex app-server`;
- does not read SQLite, JSONL, auth, or production cache records;
- does not write production appearance or quota preferences.

Refresh resolves to the selected fixture and therefore cannot drift to live
data.

## Current and Candidate Workflow

`Current` always renders the approved production component and tokens.

`Candidate` is a development-only registration point. A future experiment may
provide candidate tokens, composition, or a feature-gated view without changing
the production selection. The preview window can switch between both under the
same fixture.

After user approval:

1. the candidate change is promoted into the production implementation;
2. `Current` becomes the newly approved result;
3. the temporary candidate registration is removed;
4. production tests and the Release build run before installation.

This avoids maintaining a permanent forked panel tree.

## Safe Process-Switch Workflow

`scripts/run-developer-preview.sh` performs a reversible one-process switch:

1. validate the installed bundle identity and executable path;
2. build the Debug app before stopping anything;
3. capture whether the exact installed executable is currently running, then
   stop only that PID and wait for exit;
4. launch the development build with `--developer-preview`, require a bounded
   window-readiness handshake, and wait for exit;
5. restore the installed production app only when it was originally running,
   and report success only after the exact executable becomes ready.

The script never copies over, renames, or replaces the installed app bundle. If
the Debug build fails, the running production app is not stopped. If the
development launch fails after the switch, restoration is attempted immediately
and the script exits nonzero.

The switching behavior is explicit in script output so a preview session never
looks like an unexplained production outage.

## Code Organization

Developer-only types live under:

```text
Sources/CodexLimitPeek/DeveloperTools/
```

Focused responsibilities:

- `DeveloperPreviewLaunchConfiguration`: Debug-only launch parsing.
- `DeveloperPreviewScenario`: finite fixture definitions.
- `DeveloperPreviewEnvironment`: isolated stores and providers.
- `DeveloperPreviewCoordinator`: standard-window lifecycle.
- `DeveloperPreviewView`: controls and staged production surface.
- `DeveloperPreviewCandidate`: temporary candidate registration point.

Shared production code may expose narrow dependency-injection seams, but their
defaults must preserve existing Release behavior.

## Migration From the Rejected Demo Host

- Remove the `demo` packaging variant from `scripts/build-app.sh`.
- Remove `scripts/run-demo-panel.sh`.
- Remove the separate Demo app name, executable name, and bundle identifier.
- Adapt reusable fixed-data and coordinator code from `Demo/` into
  `DeveloperTools/` behind `DEVELOPER_TOOLS`.
- Replace `--demo-panel`, `--demo-theme`, and `--demo-layout` with the single
  developer entry plus in-window scenario controls.
- Update README development instructions to describe the reversible developer
  preview session.

## Failure Handling

- Invalid developer arguments fail before the production process is stopped.
- Failure to create the developer window exits the automated preview session and
  triggers production restoration.
- Closing the preview closes More and color-panel auxiliary windows first.
- Fixture or candidate construction failures remain inside the developer window
  and never fall through to live quota providers.
- Release builds remain valid when every developer-only file compiles to no
  declarations under the compilation condition.

## Verification

Automated verification covers:

- Debug and Release compilation;
- absence of developer entry behavior in Release;
- launch parsing and repeated-window reuse in Debug;
- fixture values and side-effect isolation;
- production preference preservation;
- process-switch failure ordering and restoration behavior;
- existing full test suite and documentation validation.

Computer Use verification covers:

- the named developer window is discoverable by accessibility;
- theme, layout, state, and implementation controls are operable;
- Refresh remains deterministic;
- More and appearance navigation use the real production wiring;
- closing the session removes the developer process;
- the installed production menu-bar app is restored afterward.

The workflow is accepted only when the production preference snapshot is
unchanged before and after the session.
