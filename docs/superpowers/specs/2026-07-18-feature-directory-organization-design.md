# Feature Directory Organization Design

**Status:** Implemented and validated

**Date:** 2026-07-18

## Context

After the large-file refactor, the `CodexLimitPeek` executable target contains
23 Swift files and the test target contains 18 Swift files. Both targets still
store every file in one flat directory. The files now have clear feature
boundaries, so the filesystem should reflect those boundaries.

This work changes file locations only. Swift declarations, file contents,
module membership, access control, runtime behavior, tests, scripts, assets,
and build products remain unchanged.

## Goals

- Organize production files by product responsibility.
- Organize tests into coarse feature groups.
- Keep directory depth low and predictable.
- Update the README project tree to match the active source layout.
- Preserve SwiftPM's single executable target and single test target.
- Keep Git history recognizable as file moves.

## Non-goals

- No Swift declaration, import, string, constant, or access-level change.
- No additional Swift target or module.
- No change to `Package.swift`.
- No source-file split, merge, or rename.
- No movement of shell scripts, documentation images, or historical plans.
- No change to build, installation, test, or documentation-rendering logic.

## Production Directory Map

```text
Sources/CodexLimitPeek/
├── App/
│   ├── AppDelegate.swift
│   └── CodexLimitPeekApp.swift
├── Quota/
│   ├── AppServerQuotaProvider.swift
│   ├── QuotaDomain.swift
│   ├── QuotaProviders.swift
│   ├── QuotaStore.swift
│   └── RefreshReliability.swift
├── MenuBar/
│   ├── CompactStatusItemView.swift
│   ├── MoreOverlayPresenter.swift
│   ├── MoreOverlayViews.swift
│   ├── PanelMetrics.swift
│   └── StatusPanelViews.swift
└── Appearance/
    ├── AppearanceStore.swift
    ├── AppearanceTheme.swift
    ├── ThemeChromeViews.swift
    ├── ThemeVisualRecipe.swift
    └── Editor/
        ├── AppearanceColorPanelCoordinator.swift
        ├── AppearanceEditorComponents.swift
        ├── AppearanceEditorSupport.swift
        ├── AppearanceEditorTypography.swift
        ├── AppearanceEditorView.swift
        ├── StateColorsEditorView.swift
        └── StatusItemEditorView.swift
```

`MenuBar` owns both the compact status item and the panels opened from it.
`Appearance/Editor` is the only nested feature folder because it contains
seven tightly related files. Smaller one-file or two-file directories are
intentionally avoided.

## Test Directory Map

```text
Tests/CodexLimitPeekTests/
├── Application/
│   ├── AppDelegateLifecycleTests.swift
│   └── MoreOverlayTests.swift
├── Quota/
│   ├── AppServerQuotaProviderTests.swift
│   ├── CodexSessionQuotaProviderTests.swift
│   ├── QuotaStoreTests.swift
│   └── RefreshReliabilityTests.swift
├── Appearance/
│   ├── AppearanceColorPanelCoordinatorTests.swift
│   ├── AppearanceEditorTypographyTests.swift
│   ├── AppearanceResetConfirmationTests.swift
│   ├── AppearanceStoreTests.swift
│   ├── AppearanceThemeTests.swift
│   ├── StatusItemAppearanceTests.swift
│   ├── StatusItemEditorTests.swift
│   ├── ThemeSurfaceShadowRenderingTests.swift
│   └── ThemeVisualRecipeTests.swift
└── Documentation/
    ├── DocumentationPreviewRenderer.swift
    ├── DocumentationPreviewRendererTests.swift
    └── DocumentationPreviewSeamTests.swift
```

The test hierarchy is intentionally coarser than the production hierarchy.
It groups tests by the behavior they verify rather than trying to reproduce
every production subdirectory.

## Directories That Remain Unchanged

- `scripts/` remains flat because CI, contributor documentation, and scripts
  reference its current paths.
- `docs/images/` retains its strict four-image rendering and validation
  contract.
- `docs/superpowers/plans/` and `docs/superpowers/specs/` remain historical
  records. Existing documents keep their original source paths.
- `.github/` remains unchanged.
- ignored `build/` and `.superpowers/` directories are not part of this
  refactor.

## SwiftPM and Access-control Boundaries

`Package.swift` declares targets by name without `path`, `sources`, or
`exclude` overrides. SwiftPM recursively discovers Swift files below:

- `Sources/CodexLimitPeek`
- `Tests/CodexLimitPeekTests`

Moving a complete file into a subdirectory does not create a Swift namespace
or module. Every declaration remains in its current target. File-level
`private` declarations remain in the same physical file, so access control is
unchanged.

No active script, CI workflow, source file, or test hard-codes an individual
Swift source path. Test filtering uses suite names rather than file paths.

## README Update

Replace the stale flat project tree with a conceptual feature tree showing:

- the four production groups
- the nested appearance editor
- the four test groups
- unchanged script and documentation locations

Use representative filenames and ellipses rather than listing every file, so
the README does not become stale whenever a new file is added.

## Verification

The organization is complete only when:

- all 41 Swift files are present exactly once
- file contents match their pre-move hashes
- `Package.swift` remains unchanged
- `git diff --check` passes
- all 187 tests pass
- documentation preview determinism passes
- documentation image hashes remain unchanged
- source installation checks pass
- the Release application builds
- Git reports file renames rather than delete-and-recreate content changes

## Expected Outcome

The application and test behavior remain identical. Contributors can locate
app lifecycle, quota, menu-bar, appearance, and documentation code directly
from the directory tree without introducing new module boundaries or path
maintenance in build scripts.
