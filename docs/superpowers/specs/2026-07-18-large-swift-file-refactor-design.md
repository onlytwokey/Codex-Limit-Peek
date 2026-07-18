# Large Swift File Refactor Design

**Status:** Implemented and validated

**Date:** 2026-07-18

## Context

Codex Limit Peek remains small as an installed application, but two source
files now contain several unrelated responsibilities:

- `CodexLimitPeekApp.swift`: 2,181 lines
- `AppearanceEditorView.swift`: 1,992 lines

The installed application is not being redesigned. This work only reorganizes
existing declarations into focused files so future changes can be made with
smaller review and regression surfaces.

The repository-local `.build` cache was removed before this refactor. SwiftPM
will regenerate it during verification.

## Goals

- Reduce both large files to focused entry or root-view files.
- Group declarations by existing responsibility.
- Preserve all runtime behavior, UI output, persistence keys, window ordering,
  event routing, accessibility behavior, and test seams.
- Keep the executable target's external API unchanged.
- Avoid introducing new abstractions solely for the sake of moving code.
- Keep every source file created or changed by the refactor below 900 lines.

## Non-goals

- No visual redesign or layout adjustment.
- No change to the five-window panel and overlay stack.
- No change to refresh timing, fallback behavior, notifications, or speech.
- No change to color-picker or reset behavior.
- No persistence migration or key rename.
- No package, dependency, resource, or build-script change.
- No performance optimization or binary stripping.

## Refactor Strategy

This is a mechanical extraction. Existing top-level declarations move as whole
units. Function bodies, property bodies, constants, strings, and callback
wiring remain unchanged.

Imports may be reduced to the frameworks required by each destination file.
Formatting may change only where a declaration boundary requires it.

No declaration becomes `public` or `open`.

## `CodexLimitPeekApp.swift` Decomposition

### `CodexLimitPeekApp.swift`

Retains only the SwiftUI application entry point:

- `CodexLimitPeekApp`

### `PanelMetrics.swift`

Contains:

- `PanelMetrics`

This keeps screen placement and shadow-frame geometry independent from the
application delegate.

### `AppDelegate.swift`

Contains:

- `AppDelegate`

The delegate continues to own the status item, primary panel pair, global
outside-click monitor, stores, and `MoreOverlayPresenter`. No ownership or
lifecycle change is permitted.

### `CompactStatusItemView.swift`

Contains:

- `CompactStatusItemView`

Drawing, hit testing, accessibility, intrinsic sizing, and menu-bar rendering
remain byte-for-byte equivalent in behavior.

### `StatusPanelViews.swift`

Contains the existing panel and action views:

- `StatusPanelView`
- `StatusPanelShadowView`
- `PanelGlassBackground`
- `RefreshIconButton`
- `PanelIconFrame`
- `MoreActionsMenu`
- `ActionsPopover`
- `BroadcastIntervalButton`
- `ActionMenuRow`
- the file-private `themedIconSurface` view helper

The private view helper remains in the same file as its callers, so its access
level does not change.

### `QuotaStore.swift`

Contains:

- `QuotaStore`
- `QuotaDisplayMode`
- `QuotaSnapshot`
- the file-private `CacheKey`

`CacheKey` must remain in the same file as both `QuotaStore` and
`QuotaSnapshot`. This preserves its file-level privacy and prevents constant
duplication.

### `QuotaDomain.swift`

Contains:

- `RefreshHealth`
- `QuotaRefreshResult`
- `QuotaProvider`
- `RateLimitRecord`
- `RateLimitWindow`
- `QuotaStatusFormatter`

These declarations describe refresh and quota data without owning refresh
lifecycle state or filesystem access.

### `QuotaProviders.swift`

Contains:

- `CompositeQuotaProvider`
- `CodexLogQuotaProvider`
- `CodexSessionQuotaProvider`
- the file-private `SessionFile`

`SessionFile` remains beside `CodexSessionQuotaProvider`, preserving its
current access level.

## `AppearanceEditorView.swift` Decomposition

### `AppearanceEditorView.swift`

Retains:

- `AppearanceEditorView`
- the private `AppearanceLivePreview`

The file remains the root appearance page and owns its current local
confirmation state and bindings.

### `AppearanceEditorSupport.swift`

Contains:

- `AppearanceEditorInitialScrollTarget`
- `AppearanceEditorDocumentationMetrics`
- the private environment key and its module-internal `EnvironmentValues`
  property
- `BrutalEditorStyle`
- `AppearanceEditorMetrics`
- `AppearanceResetConfirmationState`
- `StatusItemEditorField`
- `AppearanceEditorPalette`

The private environment key remains beside its environment property.

### `StateColorsEditorView.swift`

Contains:

- `StateColorsEditorView`

### `StatusItemEditorView.swift`

Contains:

- `StatusItemEditorView`

### `AppearanceEditorComponents.swift`

Contains:

- `ThemeChoiceButton`
- the private `ThemeChoiceChromeThumbnail`
- `AppearanceEditorSection`
- `BrutalSlider`
- `AppearanceColorRow`
- `AppearanceCustomColorButton`
- the shared `brutalSectionDivider` view helper
- the private `AppearanceColor.editorHexLabel` helper

Private helpers used only inside this file remain private.

## Required Internal Visibility

Several current file-level `private` declarations are shared across two or
more appearance pages. Swift does not allow those declarations to remain
file-private after the pages move to separate files.

Only the following shared declarations become module-internal:

- `BrutalEditorStyle`
- `ThemeChoiceButton`
- `AppearanceEditorSection`
- `BrutalSlider`
- `AppearanceColorRow`
- `AppearanceEditorPalette`
- `brutalSectionDivider`

This is a compile-time visibility change inside the `CodexLimitPeek`
executable target only. It does not expose an API to other modules, packages,
applications, or processes. It does not change layout, runtime dispatch,
memory ownership, persistence, or installed application permissions.

Names retain the existing `AppearanceEditor` or editor-specific context where
already present. No general-purpose reuse is introduced.

## Data and Event Flow

All existing flows remain unchanged:

1. `AppDelegate` owns `QuotaStore`, `AppearanceStore`, and
   `MoreOverlayPresenter`.
2. `QuotaStore` refreshes through the existing `QuotaProvider` boundary.
3. Published quota and appearance changes update the status item and panel.
4. Appearance views continue to mutate only `AppearanceStore`.
5. Color-panel callbacks retain the captured theme and token.
6. The overlay presenter retains its existing dismissal and window-order
   policies.

Moving declarations does not add a new coordinator, protocol, event, task,
timer, or retained object.

## Failure and Edge-case Boundaries

- If a moved declaration fails to compile because of file-level privacy, only
  the approved shared appearance helpers may become module-internal.
- `CacheKey`, `SessionFile`, the environment key, and single-file view helpers
  must not have their visibility widened.
- No implementation may duplicate a private type or constant to avoid a
  compiler error.
- No test is weakened or removed to make the split pass.
- If a mechanical move exposes an unexpected dependency cycle, the affected
  declarations remain together rather than introducing a new abstraction.

## Verification

The implementation is complete only when all of the following pass:

- `git diff --check`
- `scripts/test.sh --quiet`
- all existing tests pass; the current baseline is 187 tests
- `scripts/render-doc-previews.sh --check`
- `scripts/test-install.sh`
- `scripts/build-app.sh`

Additional review checks:

- No `public` or `open` declaration is added.
- No persistence key or user-facing string changes.
- No production declaration is duplicated.
- No new source file exceeds 900 lines.
- `CodexLimitPeekApp.swift` contains only the app entry point.
- `AppearanceEditorView.swift` contains only the root page and its private
  live preview.
- The generated documentation image hashes remain unchanged.

## Expected Outcome

The installed application behaves exactly as before. The source tree gains
focused files with smaller review surfaces, while the existing tests continue
to guard window layering, scroll routing, color editing, theme reset, quota
refresh, appearance rendering, and documentation output.
