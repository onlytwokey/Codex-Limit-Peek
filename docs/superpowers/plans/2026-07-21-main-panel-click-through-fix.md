# Main Panel Click-Through Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure every click inside the visible main quota panel dismisses only the settings overlay, while true outside clicks continue to dismiss both windows.

**Architecture:** Preserve the existing `panelWindow` and `panelShadowWindow` split. Make only the interactive `panelWindow` minimally nontransparent at the AppKit window level so Window Server routes empty-shell clicks into the application; keep the visual shadow window clear and mouse-ignoring.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSPanel`, Swift Testing, Swift Package Manager, project shell scripts.

---

## File Structure

- Modify `Tests/CodexLimitPeekTests/Application/AppDelegateLifecycleTests.swift` to lock the interaction-window and shadow-window mouse-routing contract.
- Modify `Sources/CodexLimitPeek/App/AppDelegate.swift` to give the main interaction panel a visually imperceptible nonzero backing alpha.
- Do not modify `StatusPanelView`, `ThemePanelComposition`, `MoreOverlayPresenter`, theme recipes, or dismissal policy.

### Task 1: Add the Main-Panel Hit-Testing Regression

**Files:**
- Modify: `Tests/CodexLimitPeekTests/Application/AppDelegateLifecycleTests.swift:8-24`

- [ ] **Step 1: Add failing interaction-window assertions**

Extend `panelIsCreatedOnDemandAndThenReused()` immediately after the identity assertion and retain the existing child-window assertions:

```swift
#expect(firstPanel === secondPanel)
#expect(!firstPanel.ignoresMouseEvents)

let interactionAlpha = firstPanel.backgroundColor.alphaComponent
#expect(interactionAlpha > 0)
#expect(interactionAlpha <= 0.001)

let childWindows = try #require(firstPanel.childWindows)
#expect(childWindows.count == 1)
#expect(childWindows[0].backgroundColor.alphaComponent == 0)
#expect(childWindows[0].ignoresMouseEvents)
#expect(childWindows[0].level == firstPanel.level)
```

The two alpha checks express the required contract: the interaction window must participate in hit testing without becoming visibly opaque, while the visual shadow window remains fully clear and click-through.

- [ ] **Step 2: Run the focused test and confirm the regression is exposed**

Run:

```bash
scripts/test.sh --quiet --filter AppDelegateLifecycleTests.panelIsCreatedOnDemandAndThenReused
```

Expected: FAIL at `#expect(interactionAlpha > 0)` because `panelWindow.backgroundColor` is currently `.clear`.

### Task 2: Make the Full Main Panel Interactive

**Files:**
- Modify: `Sources/CodexLimitPeek/App/AppDelegate.swift:94`
- Test: `Tests/CodexLimitPeekTests/Application/AppDelegateLifecycleTests.swift`

- [ ] **Step 1: Apply the minimal AppKit backing change**

Replace:

```swift
panel.backgroundColor = .clear
```

with:

```swift
panel.backgroundColor = NSColor(
    calibratedWhite: 0,
    alpha: 0.001
)
```

Do not change `panel.isOpaque`, `panel.hasShadow`, the SwiftUI root view, or any `shadowPanel` property.

- [ ] **Step 2: Run the focused lifecycle test**

Run:

```bash
scripts/test.sh --quiet --filter AppDelegateLifecycleTests.panelIsCreatedOnDemandAndThenReused
```

Expected: PASS. The interaction alpha is nonzero and no greater than `0.001`; the shadow child remains clear and ignores mouse events.

- [ ] **Step 3: Run the complete lifecycle and overlay suites**

Run:

```bash
scripts/test.sh --quiet --filter AppDelegateLifecycleTests
scripts/test.sh --quiet --filter MoreOverlayTests
```

Expected: both suites PASS. Existing `.parentPanel -> .closeOverlay` and outside-click behavior remain unchanged.

- [ ] **Step 4: Review the scoped diff**

Run:

```bash
git diff --check
git diff -- Sources/CodexLimitPeek/App/AppDelegate.swift Tests/CodexLimitPeekTests/Application/AppDelegateLifecycleTests.swift
```

Expected: no whitespace errors, and the production diff contains only the nonzero AppKit backing color while the test diff contains only the new window-routing assertions.

- [ ] **Step 5: Commit the tested source change**

Run:

```bash
git add Sources/CodexLimitPeek/App/AppDelegate.swift Tests/CodexLimitPeekTests/Application/AppDelegateLifecycleTests.swift
git commit -m "fix: prevent main panel click-through"
```

Expected: one commit containing exactly the source and regression-test files.

### Task 3: Verify, Install, and Exercise the Fix

**Files:**
- Verify: `Sources/CodexLimitPeek/App/AppDelegate.swift`
- Verify: `Tests/CodexLimitPeekTests/Application/AppDelegateLifecycleTests.swift`

- [ ] **Step 1: Run the complete automated test suite**

Run:

```bash
scripts/test.sh
```

Expected: all test suites PASS, including `AppDelegateLifecycleTests` and `MoreOverlayTests`.

- [ ] **Step 2: Build and install through the supported deployment path**

Run:

```bash
scripts/install.sh
```

Expected: the Release build succeeds, the temporary SwiftPM scratch directory is removed on exit, and the updated application is installed through the project script.

- [ ] **Step 3: Restart the installed application**

Run:

```bash
scripts/restart.sh
```

Expected: the updated Codex Limit Peek process launches successfully.

- [ ] **Step 4: Exercise the Window Server interaction contract**

Perform this acceptance sequence:

1. Open the main quota panel from the menu bar.
2. Open More, then enter the appearance settings page.
3. Click an empty part of the visible main-panel shell outside the quota card.
4. Confirm that the settings page closes and the main quota panel remains visible.
5. Reopen the settings page and click outside the entire main panel.
6. Confirm that both the settings page and main quota panel close.
7. Repeat step 3 once on the title-row padding to verify that the fix is not limited to one shell coordinate.

Expected: all internal panel clicks follow the local overlay-dismissal path, while the true outside click follows `AppDelegate.closePanel()`.

- [ ] **Step 5: Confirm repository state**

Run:

```bash
git status --short
git log -3 --oneline
```

Expected: no unintended modified files; the click-through fix commit appears
above the implementation-plan and approved design-spec commits.
