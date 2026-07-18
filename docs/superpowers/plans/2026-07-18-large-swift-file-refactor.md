# Large Swift File Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mechanically split `CodexLimitPeekApp.swift` and `AppearanceEditorView.swift` into focused files without changing runtime behavior, UI, persistence, or external API.

**Architecture:** Preserve every existing top-level declaration and its implementation while moving complete declaration blocks into responsibility-focused Swift files. File-private dependencies remain co-located; only the seven appearance-editor helpers approved in the design become module-internal so the three editor pages can compile in separate files.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Combine, AVFoundation, UserNotifications, Swift Package Manager, Swift Testing

---

## File Map

### Application and quota files

- Keep: `Sources/CodexLimitPeek/CodexLimitPeekApp.swift`
  - `CodexLimitPeekApp`
- Create: `Sources/CodexLimitPeek/PanelMetrics.swift`
  - `PanelMetrics`
- Create: `Sources/CodexLimitPeek/AppDelegate.swift`
  - `AppDelegate`
- Create: `Sources/CodexLimitPeek/CompactStatusItemView.swift`
  - `CompactStatusItemView`
- Create: `Sources/CodexLimitPeek/StatusPanelViews.swift`
  - `StatusPanelView`
  - `StatusPanelShadowView`
  - `PanelGlassBackground`
  - private `View.themedIconSurface`
  - `RefreshIconButton`
  - `PanelIconFrame`
  - `MoreActionsMenu`
  - `ActionsPopover`
  - `BroadcastIntervalButton`
  - `ActionMenuRow`
- Create: `Sources/CodexLimitPeek/QuotaStore.swift`
  - `QuotaStore`
  - `QuotaDisplayMode`
  - `QuotaSnapshot`
  - private `CacheKey`
- Create: `Sources/CodexLimitPeek/QuotaDomain.swift`
  - `RefreshHealth`
  - `QuotaRefreshResult`
  - `QuotaProvider`
  - `RateLimitRecord`
  - `RateLimitWindow`
  - `QuotaStatusFormatter`
- Create: `Sources/CodexLimitPeek/QuotaProviders.swift`
  - `CompositeQuotaProvider`
  - `CodexLogQuotaProvider`
  - `CodexSessionQuotaProvider`
  - private `SessionFile`

### Appearance editor files

- Keep: `Sources/CodexLimitPeek/AppearanceEditorView.swift`
  - `AppearanceEditorView`
  - private `AppearanceLivePreview`
- Create: `Sources/CodexLimitPeek/AppearanceEditorSupport.swift`
  - `AppearanceEditorInitialScrollTarget`
  - `AppearanceEditorDocumentationMetrics`
  - private `AppearanceEditorInitialScrollTargetKey`
  - internal `EnvironmentValues.appearanceEditorInitialScrollTarget`
  - internal `BrutalEditorStyle`
  - `AppearanceEditorMetrics`
  - `AppearanceResetConfirmationState`
  - `StatusItemEditorField`
  - internal `AppearanceEditorPalette`
- Create: `Sources/CodexLimitPeek/StateColorsEditorView.swift`
  - `StateColorsEditorView`
- Create: `Sources/CodexLimitPeek/StatusItemEditorView.swift`
  - `StatusItemEditorView`
- Create: `Sources/CodexLimitPeek/AppearanceEditorComponents.swift`
  - internal `ThemeChoiceButton`
  - private `ThemeChoiceChromeThumbnail`
  - internal `AppearanceEditorSection`
  - internal `BrutalSlider`
  - internal `AppearanceColorRow`
  - `AppearanceCustomColorButton`
  - internal `View.brutalSectionDivider`
  - private `AppearanceColor.editorHexLabel`

## Task 1: Establish the Branch Baseline

**Files:**

- Verify: all production and test files

- [ ] **Step 1: Confirm the branch and clean worktree**

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

- [ ] **Step 2: Rebuild the removed SwiftPM cache and run the baseline**

Run:

```bash
scripts/test.sh --quiet
```

Expected: all 187 existing tests pass.

- [ ] **Step 3: Record documentation image hashes**

Run:

```bash
shasum -a 256 docs/images/*.png
```

Expected: four hashes are captured for post-refactor comparison.

## Task 2: Extract the Application Shell and Panel Views

**Files:**

- Modify: `Sources/CodexLimitPeek/CodexLimitPeekApp.swift`
- Create: `Sources/CodexLimitPeek/PanelMetrics.swift`
- Create: `Sources/CodexLimitPeek/AppDelegate.swift`
- Create: `Sources/CodexLimitPeek/CompactStatusItemView.swift`
- Create: `Sources/CodexLimitPeek/StatusPanelViews.swift`

- [ ] **Step 1: Move application declarations as complete blocks**

Use this target structure:

```swift
// CodexLimitPeekApp.swift
import SwiftUI

@main
struct CodexLimitPeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

Move `PanelMetrics`, `AppDelegate`, `CompactStatusItemView`, and all declarations
from `StatusPanelView` through `ActionMenuRow` to the exact destination files
listed in the file map. Preserve declaration bodies verbatim.

- [ ] **Step 2: Preserve file-private panel helpers**

Move the complete `private extension View` declaration that defines
`themedIconSurface(appearance:isEnabled:)` into `StatusPanelViews.swift`
without editing its signature or body. Keep it in that file with
`PanelIconFrame`, its only caller.

- [ ] **Step 3: Compile the application split**

Run:

```bash
swift build
```

Expected: build succeeds with no duplicate or missing declarations.

- [ ] **Step 4: Run application lifecycle and overlay tests**

Run:

```bash
scripts/test.sh --quiet --filter AppDelegateLifecycleTests
scripts/test.sh --quiet --filter MoreOverlayTests
```

Expected: both suites pass.

## Task 3: Extract Quota State, Models, and Providers

**Files:**

- Modify: `Sources/CodexLimitPeek/CodexLimitPeekApp.swift`
- Create: `Sources/CodexLimitPeek/QuotaStore.swift`
- Create: `Sources/CodexLimitPeek/QuotaDomain.swift`
- Create: `Sources/CodexLimitPeek/QuotaProviders.swift`

- [ ] **Step 1: Move store and cache-coupled declarations**

Move the complete `QuotaStore`, `QuotaDisplayMode`, `QuotaSnapshot`, and
private `CacheKey` declarations together into `QuotaStore.swift`. Preserve
every declaration signature and body, including both `QuotaDisplayMode` cases
and every `CacheKey` string.

Use imports:

```swift
import AppKit
import AVFoundation
import Combine
import SwiftUI
import UserNotifications
```

- [ ] **Step 2: Move quota domain declarations**

Move `RefreshHealth`, `QuotaRefreshResult`, `QuotaProvider`,
`RateLimitRecord`, `RateLimitWindow`, and `QuotaStatusFormatter` unchanged into
`QuotaDomain.swift` with:

```swift
import AppKit
import Foundation
import SwiftUI
```

- [ ] **Step 3: Move providers and their private helper**

Move `CompositeQuotaProvider`, `CodexLogQuotaProvider`,
`CodexSessionQuotaProvider`, and private `SessionFile` unchanged into
`QuotaProviders.swift` with:

```swift
import Foundation
```

Keep `SessionFile` private and in the same file as its only consumer.

- [ ] **Step 4: Run quota-focused tests**

Run:

```bash
scripts/test.sh --quiet --filter QuotaStoreTests
scripts/test.sh --quiet --filter AppServerQuotaProviderTests
scripts/test.sh --quiet --filter CodexSessionQuotaProviderTests
scripts/test.sh --quiet --filter RefreshReliabilityTests
```

Expected: all four suites pass.

## Task 4: Extract Appearance Editor Support and Components

**Files:**

- Modify: `Sources/CodexLimitPeek/AppearanceEditorView.swift`
- Create: `Sources/CodexLimitPeek/AppearanceEditorSupport.swift`
- Create: `Sources/CodexLimitPeek/AppearanceEditorComponents.swift`

- [ ] **Step 1: Move support declarations**

Move the navigation target, documentation metrics, environment key and
property, style palette, control metrics, reset state, status-item field, and
color palette to `AppearanceEditorSupport.swift`.

Preserve these access boundaries:

```swift
private struct AppearanceEditorInitialScrollTargetKey: EnvironmentKey {
    static let defaultValue: AppearanceEditorInitialScrollTarget? = nil
}

extension EnvironmentValues {
    var appearanceEditorInitialScrollTarget:
        AppearanceEditorInitialScrollTarget?
    {
        get { self[AppearanceEditorInitialScrollTargetKey.self] }
        set { self[AppearanceEditorInitialScrollTargetKey.self] = newValue }
    }
}
```

Move `BrutalEditorStyle` and `AppearanceEditorPalette` with their complete
computed-property and switch bodies. Remove only their top-level `private`
keywords.

- [ ] **Step 2: Move shared components**

Move the exact existing component bodies into
`AppearanceEditorComponents.swift`. Remove `private` only from:

```swift
struct ThemeChoiceButton: View
struct AppearanceEditorSection<Content: View>: View
struct BrutalSlider: View
struct AppearanceColorRow: View

extension View {
    func brutalSectionDivider() -> some View
}
```

Keep `ThemeChoiceChromeThumbnail` and
`AppearanceColor.editorHexLabel` private. `AppearanceCustomColorButton`
already remains module-internal.

- [ ] **Step 3: Compile the support split**

Run:

```bash
swift build
```

Expected: build succeeds without widening any additional declaration.

## Task 5: Extract the Appearance Subpages

**Files:**

- Modify: `Sources/CodexLimitPeek/AppearanceEditorView.swift`
- Create: `Sources/CodexLimitPeek/StateColorsEditorView.swift`
- Create: `Sources/CodexLimitPeek/StatusItemEditorView.swift`

- [ ] **Step 1: Move both page views unchanged**

Move the complete `StateColorsEditorView` declaration to
`StateColorsEditorView.swift` and the complete `StatusItemEditorView`
declaration to `StatusItemEditorView.swift`.

Each file begins with:

```swift
import Foundation
import SwiftUI
```

- [ ] **Step 2: Keep the root and private preview together**

`AppearanceEditorView.swift` must contain only the existing complete
`AppearanceEditorView` and `AppearanceLivePreview` declarations after the
other blocks move. Its import prefix remains:

```swift
import Foundation
import SwiftUI
```

- [ ] **Step 3: Run appearance-focused tests**

Run:

```bash
scripts/test.sh --quiet --filter AppearanceEditorTypographyTests
scripts/test.sh --quiet --filter AppearanceResetConfirmationTests
scripts/test.sh --quiet --filter StatusItemEditorTests
scripts/test.sh --quiet --filter AppearanceColorPanelCoordinatorTests
scripts/test.sh --quiet --filter AppearanceStoreTests
```

Expected: all five suites pass.

## Task 6: Verify Mechanical Equivalence

**Files:**

- Verify: `Sources/CodexLimitPeek/*.swift`
- Verify: `docs/images/*.png`

- [ ] **Step 1: Check file sizes and access changes**

Run:

```bash
wc -l Sources/CodexLimitPeek/*.swift
rg -n "^(public|open) " Sources/CodexLimitPeek
```

Expected:

- every new or modified source file is below 900 lines
- no new `public` or `open` declaration exists

- [ ] **Step 2: Check formatting and complete test suite**

Run:

```bash
git diff --check
scripts/test.sh --quiet
```

Expected: diff check succeeds and all 187 tests pass.

- [ ] **Step 3: Verify documentation determinism**

Run:

```bash
scripts/render-doc-previews.sh --check
shasum -a 256 docs/images/*.png
```

Expected: renderer check succeeds and all four PNG hashes match Task 1.

- [ ] **Step 4: Verify installation and release build**

Run:

```bash
scripts/test-install.sh
scripts/build-app.sh
```

Expected:

- source installation checks pass
- release application builds successfully

- [ ] **Step 5: Review the complete diff**

Run:

```bash
git status -sb
git diff --stat
git diff --color-moved=dimmed-zebra
```

Expected: only the design/plan documents and mechanical Swift declaration moves
appear; no production string, persistence key, constant value, or behavior is
changed beyond the approved internal visibility adjustments.

## Task 7: Commit the Refactor

**Files:**

- Stage: all new and modified Swift files
- Stage: `docs/superpowers/plans/2026-07-18-large-swift-file-refactor.md`

- [ ] **Step 1: Stage explicit paths**

Run:

```bash
git add Sources/CodexLimitPeek/CodexLimitPeekApp.swift \
  Sources/CodexLimitPeek/PanelMetrics.swift \
  Sources/CodexLimitPeek/AppDelegate.swift \
  Sources/CodexLimitPeek/CompactStatusItemView.swift \
  Sources/CodexLimitPeek/StatusPanelViews.swift \
  Sources/CodexLimitPeek/QuotaStore.swift \
  Sources/CodexLimitPeek/QuotaDomain.swift \
  Sources/CodexLimitPeek/QuotaProviders.swift \
  Sources/CodexLimitPeek/AppearanceEditorView.swift \
  Sources/CodexLimitPeek/AppearanceEditorSupport.swift \
  Sources/CodexLimitPeek/AppearanceEditorComponents.swift \
  Sources/CodexLimitPeek/StateColorsEditorView.swift \
  Sources/CodexLimitPeek/StatusItemEditorView.swift \
  docs/superpowers/plans/2026-07-18-large-swift-file-refactor.md
```

- [ ] **Step 2: Commit**

Run:

```bash
git commit -m "refactor: split large Swift source files"
```

Expected: one implementation commit is created on
`codex/refactor-large-swift-files`.
