# Feature Directory Organization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all production and test Swift files into approved feature directories without changing file contents or runtime behavior.

**Architecture:** Keep the existing `CodexLimitPeek` executable and test targets intact while organizing their recursively discovered source files by feature. Use complete-file moves only, update the README conceptual tree, then verify content hashes, rename detection, tests, documentation rendering, installation, and Release build.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftUI, AppKit, Swift Testing, Bash, Git

---

## Task 1: Record the Pre-move Baseline

**Files:**

- Verify: `Sources/CodexLimitPeek/*.swift`
- Verify: `Tests/CodexLimitPeekTests/*.swift`
- Verify: `docs/images/*.png`

- [ ] **Step 1: Confirm branch and worktree**

Run:

```bash
git status -sb
git branch --show-current
```

Expected:

```text
## codex/refactor-large-swift-files
codex/refactor-large-swift-files
```

- [ ] **Step 2: Record all Swift content hashes**

Run:

```bash
find Sources/CodexLimitPeek Tests/CodexLimitPeekTests \
  -type f -name '*.swift' -print0 \
  | sort -z \
  | xargs -0 shasum -a 256
```

Expected: 41 file hashes, with 23 production files and 18 test files.

- [ ] **Step 3: Record documentation image hashes**

Run:

```bash
shasum -a 256 docs/images/*.png
```

Expected: four hashes are captured for the post-move comparison.

## Task 2: Move Production Files by Feature

**Files:**

- Move: all 23 files below `Sources/CodexLimitPeek`

- [ ] **Step 1: Move application files**

Apply these exact path mappings:

```text
Sources/CodexLimitPeek/AppDelegate.swift
  -> Sources/CodexLimitPeek/App/AppDelegate.swift
Sources/CodexLimitPeek/CodexLimitPeekApp.swift
  -> Sources/CodexLimitPeek/App/CodexLimitPeekApp.swift
```

- [ ] **Step 2: Move quota files**

Apply these exact path mappings:

```text
Sources/CodexLimitPeek/AppServerQuotaProvider.swift
  -> Sources/CodexLimitPeek/Quota/AppServerQuotaProvider.swift
Sources/CodexLimitPeek/QuotaDomain.swift
  -> Sources/CodexLimitPeek/Quota/QuotaDomain.swift
Sources/CodexLimitPeek/QuotaProviders.swift
  -> Sources/CodexLimitPeek/Quota/QuotaProviders.swift
Sources/CodexLimitPeek/QuotaStore.swift
  -> Sources/CodexLimitPeek/Quota/QuotaStore.swift
Sources/CodexLimitPeek/RefreshReliability.swift
  -> Sources/CodexLimitPeek/Quota/RefreshReliability.swift
```

- [ ] **Step 3: Move menu-bar files**

Apply these exact path mappings:

```text
Sources/CodexLimitPeek/CompactStatusItemView.swift
  -> Sources/CodexLimitPeek/MenuBar/CompactStatusItemView.swift
Sources/CodexLimitPeek/MoreOverlayPresenter.swift
  -> Sources/CodexLimitPeek/MenuBar/MoreOverlayPresenter.swift
Sources/CodexLimitPeek/MoreOverlayViews.swift
  -> Sources/CodexLimitPeek/MenuBar/MoreOverlayViews.swift
Sources/CodexLimitPeek/PanelMetrics.swift
  -> Sources/CodexLimitPeek/MenuBar/PanelMetrics.swift
Sources/CodexLimitPeek/StatusPanelViews.swift
  -> Sources/CodexLimitPeek/MenuBar/StatusPanelViews.swift
```

- [ ] **Step 4: Move appearance model and rendering files**

Apply these exact path mappings:

```text
Sources/CodexLimitPeek/AppearanceStore.swift
  -> Sources/CodexLimitPeek/Appearance/AppearanceStore.swift
Sources/CodexLimitPeek/AppearanceTheme.swift
  -> Sources/CodexLimitPeek/Appearance/AppearanceTheme.swift
Sources/CodexLimitPeek/ThemeChromeViews.swift
  -> Sources/CodexLimitPeek/Appearance/ThemeChromeViews.swift
Sources/CodexLimitPeek/ThemeVisualRecipe.swift
  -> Sources/CodexLimitPeek/Appearance/ThemeVisualRecipe.swift
```

- [ ] **Step 5: Move appearance editor files**

Apply these exact path mappings:

```text
Sources/CodexLimitPeek/AppearanceColorPanelCoordinator.swift
  -> Sources/CodexLimitPeek/Appearance/Editor/AppearanceColorPanelCoordinator.swift
Sources/CodexLimitPeek/AppearanceEditorComponents.swift
  -> Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorComponents.swift
Sources/CodexLimitPeek/AppearanceEditorSupport.swift
  -> Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorSupport.swift
Sources/CodexLimitPeek/AppearanceEditorTypography.swift
  -> Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorTypography.swift
Sources/CodexLimitPeek/AppearanceEditorView.swift
  -> Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorView.swift
Sources/CodexLimitPeek/StateColorsEditorView.swift
  -> Sources/CodexLimitPeek/Appearance/Editor/StateColorsEditorView.swift
Sources/CodexLimitPeek/StatusItemEditorView.swift
  -> Sources/CodexLimitPeek/Appearance/Editor/StatusItemEditorView.swift
```

- [ ] **Step 6: Verify production file count**

Run:

```bash
find Sources/CodexLimitPeek -type f -name '*.swift' | sort
```

Expected: exactly 23 files and no Swift file directly below
`Sources/CodexLimitPeek`.

## Task 3: Move Test Files by Behavior

**Files:**

- Move: all 18 files below `Tests/CodexLimitPeekTests`

- [ ] **Step 1: Move application tests**

```text
Tests/CodexLimitPeekTests/AppDelegateLifecycleTests.swift
  -> Tests/CodexLimitPeekTests/Application/AppDelegateLifecycleTests.swift
Tests/CodexLimitPeekTests/MoreOverlayTests.swift
  -> Tests/CodexLimitPeekTests/Application/MoreOverlayTests.swift
```

- [ ] **Step 2: Move quota tests**

```text
Tests/CodexLimitPeekTests/AppServerQuotaProviderTests.swift
  -> Tests/CodexLimitPeekTests/Quota/AppServerQuotaProviderTests.swift
Tests/CodexLimitPeekTests/CodexSessionQuotaProviderTests.swift
  -> Tests/CodexLimitPeekTests/Quota/CodexSessionQuotaProviderTests.swift
Tests/CodexLimitPeekTests/QuotaStoreTests.swift
  -> Tests/CodexLimitPeekTests/Quota/QuotaStoreTests.swift
Tests/CodexLimitPeekTests/RefreshReliabilityTests.swift
  -> Tests/CodexLimitPeekTests/Quota/RefreshReliabilityTests.swift
```

- [ ] **Step 3: Move appearance tests**

```text
Tests/CodexLimitPeekTests/AppearanceColorPanelCoordinatorTests.swift
  -> Tests/CodexLimitPeekTests/Appearance/AppearanceColorPanelCoordinatorTests.swift
Tests/CodexLimitPeekTests/AppearanceEditorTypographyTests.swift
  -> Tests/CodexLimitPeekTests/Appearance/AppearanceEditorTypographyTests.swift
Tests/CodexLimitPeekTests/AppearanceResetConfirmationTests.swift
  -> Tests/CodexLimitPeekTests/Appearance/AppearanceResetConfirmationTests.swift
Tests/CodexLimitPeekTests/AppearanceStoreTests.swift
  -> Tests/CodexLimitPeekTests/Appearance/AppearanceStoreTests.swift
Tests/CodexLimitPeekTests/AppearanceThemeTests.swift
  -> Tests/CodexLimitPeekTests/Appearance/AppearanceThemeTests.swift
Tests/CodexLimitPeekTests/StatusItemAppearanceTests.swift
  -> Tests/CodexLimitPeekTests/Appearance/StatusItemAppearanceTests.swift
Tests/CodexLimitPeekTests/StatusItemEditorTests.swift
  -> Tests/CodexLimitPeekTests/Appearance/StatusItemEditorTests.swift
Tests/CodexLimitPeekTests/ThemeSurfaceShadowRenderingTests.swift
  -> Tests/CodexLimitPeekTests/Appearance/ThemeSurfaceShadowRenderingTests.swift
Tests/CodexLimitPeekTests/ThemeVisualRecipeTests.swift
  -> Tests/CodexLimitPeekTests/Appearance/ThemeVisualRecipeTests.swift
```

- [ ] **Step 4: Move documentation renderer and tests**

```text
Tests/CodexLimitPeekTests/DocumentationPreviewRenderer.swift
  -> Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRenderer.swift
Tests/CodexLimitPeekTests/DocumentationPreviewRendererTests.swift
  -> Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRendererTests.swift
Tests/CodexLimitPeekTests/DocumentationPreviewSeamTests.swift
  -> Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewSeamTests.swift
```

- [ ] **Step 5: Verify test file count**

Run:

```bash
find Tests/CodexLimitPeekTests -type f -name '*.swift' | sort
```

Expected: exactly 18 files and no Swift file directly below
`Tests/CodexLimitPeekTests`.

## Task 4: Update the README Project Tree

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Replace the stale flat tree**

Use this conceptual tree in the README:

```text
Sources/
└── CodexLimitPeek/
    ├── App/
    ├── Quota/
    ├── MenuBar/
    └── Appearance/
        └── Editor/
Tests/
└── CodexLimitPeekTests/
    ├── Application/
    ├── Quota/
    ├── Appearance/
    └── Documentation/
```

Keep the existing `scripts/` list and show representative Swift filenames
with ellipses rather than enumerating every file.

- [ ] **Step 2: Verify active path references**

Run:

```bash
rg -n "Sources/CodexLimitPeek|Tests/CodexLimitPeekTests" \
  README.md scripts .github CONTRIBUTING.md AGENTS.md
```

Expected: no active build or test command depends on a moved individual Swift
file path.

## Task 5: Verify Content and Behavior

**Files:**

- Verify: all moved files
- Verify: `README.md`
- Verify: `docs/images/*.png`

- [ ] **Step 1: Verify move-only Swift contents**

Compare each post-move file hash to the Task 1 hash associated with the same
basename.

Run:

```bash
find Sources/CodexLimitPeek Tests/CodexLimitPeekTests \
  -type f -name '*.swift' -print0 \
  | sort -z \
  | xargs -0 shasum -a 256
```

Expected: all 41 content hashes match the baseline.

- [ ] **Step 2: Verify formatting and SwiftPM discovery**

Run:

```bash
git diff --check
scripts/test.sh --quiet
```

Expected: diff check passes and all 187 tests pass.

- [ ] **Step 3: Verify documentation rendering**

Run:

```bash
scripts/render-doc-previews.sh --check
shasum -a 256 docs/images/*.png
```

Expected: determinism checks pass and all four image hashes match Task 1.

- [ ] **Step 4: Verify installation and Release build**

Run:

```bash
scripts/test-install.sh
scripts/build-app.sh
```

Expected: source installation checks pass and the Release application builds.

- [ ] **Step 5: Review rename detection**

Run:

```bash
git diff --summary -M
git diff --stat -M
```

Expected: all 41 Swift changes appear as 100% renames, with README and the
current design/plan documents as the only content changes.

## Task 6: Commit and Clean

**Files:**

- Stage: all moved Swift files
- Stage: `README.md`
- Stage: the current design and plan documents

- [ ] **Step 1: Stage the complete organization change**

Run:

```bash
git add Sources Tests README.md \
  docs/superpowers/specs/2026-07-18-feature-directory-organization-design.md \
  docs/superpowers/plans/2026-07-18-feature-directory-organization.md
```

- [ ] **Step 2: Commit**

Run:

```bash
git commit -m "refactor: organize source and test directories"
```

Expected: the implementation commit is created on
`codex/refactor-large-swift-files`.

- [ ] **Step 3: Remove regenerated SwiftPM cache**

Verify the exact cache path and remove:

```text
/Users/lin/Applications/Codex Limit Peek Source/.build
```

Expected: `.build` is absent, the installed application remains untouched,
and `git status -sb` reports a clean branch.
