# In-App Developer Preview Implementation Plan

> **For agentic workers:** Execute inline in this workspace. Preserve the user's explicit no-commit instruction and keep every change unstaged.

**Goal:** Replace the separately packaged Demo host with a Debug-only developer preview window inside the single Codex Limit Peek app identity.

**Architecture:** SwiftPM defines `DEVELOPER_TOOLS` only for Debug. Developer-only launch parsing, fixtures, window ownership, and preview UI live under `Sources/CodexLimitPeek/DeveloperTools`, while narrow injected defaults keep production behavior unchanged. A reversible script runs one same-identity development process at a time and restores the untouched installed app afterward.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Testing, bash, Computer Use accessibility.

---

### Task 1: Restore one packaging identity and add the Debug boundary

**Files:**
- Modify: `Package.swift`
- Modify: `scripts/build-app.sh`
- Delete: `scripts/run-demo-panel.sh`
- Test: `Tests/CodexLimitPeekTests/Application/AppDelegateLifecycleTests.swift`

- [ ] Add `.define("DEVELOPER_TOOLS", .when(configuration: .debug))` to the executable target.
- [ ] Replace the `production|demo` packaging branch with a validated `release|debug` build configuration while always emitting `build/Codex Limit Peek.app`, `io.github.onlytwokey.CodexLimitPeek`, and `CodexLimitPeek`.
- [ ] Delete the separate Demo launcher.
- [ ] Run `bash -n scripts/build-app.sh` and verify an invalid configuration exits with code 2 before invoking Swift.

### Task 2: Convert launch parsing and fixtures to developer-only types

**Files:**
- Delete: `Sources/CodexLimitPeek/Demo/DemoPanelLaunchConfiguration.swift`
- Delete: `Sources/CodexLimitPeek/Demo/DemoPanelEnvironment.swift`
- Create: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewLaunchConfiguration.swift`
- Create: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewScenario.swift`
- Create: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewEnvironment.swift`
- Replace tests under: `Tests/CodexLimitPeekTests/Demo/`

- [ ] Write failing tests for `--developer-preview`, ignored unrelated arguments, and duplicate developer arguments.
- [ ] Define the parser only under `#if DEVELOPER_TOOLS` and remove theme/layout launch arguments.
- [ ] Write scenario tests covering healthy dual, weekly only, warning, danger, unavailable, and confirmed refresh failure.
- [ ] Reuse an in-memory defaults implementation and initialize `QuotaStore` with `allowsUserFacingSideEffects: false`.
- [ ] Verify refresh returns the selected fixture and production defaults remain unchanged.

### Task 3: Add the Current/Candidate preview model and window UI

**Files:**
- Create: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewCandidate.swift`
- Create: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewView.swift`
- Create: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewCoordinator.swift`
- Test: `Tests/CodexLimitPeekTests/DeveloperTools/DeveloperPreviewCoordinatorTests.swift`

- [ ] Define finite theme, scenario, and `current|candidate` selections.
- [ ] Implement a standard titled `NSWindow` with accessibility title `Codex Limit Peek Developer Preview` and one reusable instance.
- [ ] Place controls outside a 1:1 `StatusPanelView` plus `StatusPanelShadowView` stage.
- [ ] Rebuild the isolated environment when a scenario changes and preserve no fixture state outside the window.
- [ ] Attach a real `MoreOverlayPresenter` to the staged panel host.
- [ ] Verify window reuse, standard AX role, deterministic dimensions, and auxiliary-window teardown.

### Task 4: Add the in-app Debug entry

**Files:**
- Modify: `Sources/CodexLimitPeek/App/AppDelegate.swift`
- Modify: `Sources/CodexLimitPeek/MenuBar/MoreOverlayPresenter.swift`
- Modify: `Sources/CodexLimitPeek/MenuBar/MoreOverlayViews.swift`
- Modify: `Sources/CodexLimitPeek/MenuBar/StatusPanelViews.swift`
- Test: `Tests/CodexLimitPeekTests/Application/AppDelegateLifecycleTests.swift`
- Test: `Tests/CodexLimitPeekTests/Application/MoreOverlayTests.swift`

- [ ] Guard every developer coordinator property and launch branch with `#if DEVELOPER_TOOLS`.
- [ ] Pass an optional `onOpenDeveloperPreview` closure through `MoreOverlayPresenter` into `ActionsPopover`.
- [ ] Render `开发者预览` only when that closure is non-nil.
- [ ] Auto-open the developer window for `--developer-preview`; closing it terminates only launch-argument sessions.
- [ ] Verify ordinary Debug launches and all Release behavior remain on the existing production path.

### Task 5: Implement reversible process switching

**Files:**
- Create: `scripts/run-developer-preview.sh`
- Modify: `scripts/restart.sh` only if necessary to share exact installed-path resolution.

- [ ] Validate the installed app before changing process state.
- [ ] Build Debug completely before stopping `CodexLimitPeek`.
- [ ] Launch `build/Codex Limit Peek.app --developer-preview` with wait semantics.
- [ ] Restore `$HOME/Applications/Codex Limit Peek.app` on normal exit and catchable signals without overwriting it.
- [ ] Fail closed and leave production running when build or argument validation fails.
- [ ] Run shell syntax checks and targeted failure-path checks.

### Task 6: Remove rejected Demo surfaces and update documentation

**Files:**
- Delete remaining: `Sources/CodexLimitPeek/Demo/`
- Delete remaining: `Tests/CodexLimitPeekTests/Demo/`
- Modify: `README.md`
- Modify: `README.en.md`
- Keep: `docs/superpowers/specs/2026-07-22-in-app-developer-preview-design.md`

- [ ] Remove all `Codex Limit Peek Demo`, `.Demo`, `CodexLimitPeekDemo`, and `--demo-*` runtime references except migration history in the approved spec.
- [ ] Document `scripts/run-developer-preview.sh` and the one-process switch explicitly.
- [ ] Verify Release installation commands and paths are unchanged.

### Task 7: End-to-end verification

**Files:**
- Verify all modified source, tests, scripts, and documentation.

- [ ] Run focused developer tests, then the full suite.
- [ ] Build both Debug and Release configurations.
- [ ] Run `scripts/validate-doc-images.sh`, shell syntax checks, and `git diff --check`.
- [ ] Snapshot production preferences, run the developer session, and use Computer Use to operate theme, scenario, Current/Candidate, Refresh, More, and appearance navigation.
- [ ] Close the developer session, verify the installed menu-bar app is restored, and confirm the production preference snapshot is unchanged.
- [ ] Leave every change uncommitted and report any local CLT/SDK verification gate separately from source failures.
