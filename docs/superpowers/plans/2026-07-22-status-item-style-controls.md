# Status Item Style Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add independent primary/weekly status text colors and a configurable signed two-dimensional status shadow, then verify the real AppKit status item in the Debug-only Developer Preview.

**Architecture:** Persist status-only colors and opacity in a new `StatusItemStyle`, migrate the frozen v3 disk model to v4, and keep signed offsets in `StatusItemGeometry`. `AppearanceResolver.status` produces one resolved contract consumed by the AppKit production view and SwiftUI editor adapter; status-only shadow metrics avoid changing panel chrome recipes.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Combine, Swift Testing, SwiftPM, macOS Debug-only developer tools.

**Task constraint:** Do not stage or commit. Do not install or overwrite the formal app.

---

### Task 1: Freeze v3 and add the v4 status model

**Files:**
- Modify: `Sources/CodexLimitPeek/Appearance/AppearanceTheme.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/AppearanceStore.swift`
- Test: `Tests/CodexLimitPeekTests/Appearance/AppearanceStoreTests.swift`

- [ ] **Step 1: Add failing v4 defaults and migration tests**

Add tests that loop over `AppearanceThemeID.allCases` and assert:

```swift
#expect(AppearanceProfile.currentSchemaVersion == 4)
#expect(profile.statusItemStyle.primaryTextColor == nil)
#expect(profile.statusItemStyle.weeklyTextColor == nil)
#expect(profile.statusItemStyle.shadowColor == nil)
#expect(
    profile.statusItemStyle.shadowOpacity
        == ThemeVisualRecipe.default(for: theme).statusChip.shadow.opacity
)
```

Encode a `LegacyAppearanceProfileV3` under `legacyProfileV3`, load the store,
and assert that every non-shadow value survives, while:

```swift
#expect(migrated.statusItemGeometry.shadowHorizontalOffset == legacyDepth)
#expect(migrated.statusItemGeometry.shadowVerticalOffset == legacyDepth)
#expect(migrated.statusItemGeometry.shadowBlur == legacyBlur)
```

Use a legacy blur of `16` to prove migration uses the `0...20` compatibility
range. Assert that malformed v4 falls back to v3 and that saving v4 leaves the
v3 bytes unchanged.

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```sh
scripts/test.sh --filter AppearanceStoreTests
```

Expected: compilation/test failure because v4 types and keys do not exist.

- [ ] **Step 3: Add `StatusItemStyle` and signed geometry**

Implement in `AppearanceTheme.swift`:

```swift
struct StatusItemStyle: Codable, Equatable, Sendable {
    var primaryTextColor: AppearanceColor?
    var weeklyTextColor: AppearanceColor?
    var shadowColor: AppearanceColor?
    var shadowOpacity: Double

    static func `default`(for theme: AppearanceThemeID) -> Self {
        Self(
            primaryTextColor: nil,
            weeklyTextColor: nil,
            shadowColor: nil,
            shadowOpacity: ThemeVisualRecipe.default(for: theme)
                .statusChip.shadow.opacity
        )
    }

    func validated(defaultingTo defaults: Self) -> Self {
        Self(
            primaryTextColor: primaryTextColor.map {
                $0.clamped().withAlpha(1)
            },
            weeklyTextColor: weeklyTextColor.map {
                $0.clamped().withAlpha(1)
            },
            shadowColor: shadowColor.map {
                $0.clamped().withAlpha(1)
            },
            shadowOpacity: shadowOpacity.isFinite
                ? min(max(shadowOpacity, 0), 1)
                : defaults.shadowOpacity
        )
    }
}
```

Replace `StatusItemGeometry.shadowDepth` with
`shadowHorizontalOffset` and `shadowVerticalOffset`. Use an editor range of
`-10...10`, step `0.5`, an offset compatibility range of `-20...20`, preserve
blur compatibility at `0...20`, and validate signed values without converting
them to positive magnitudes.

Advance `AppearanceProfile` to v4, add `statusItemStyle`, validate it, and add
the new field to all three defaults.

- [ ] **Step 4: Implement the frozen v3 migration chain**

Add the exact disk types:

```swift
struct LegacyStatusItemGeometryV3: Codable, Equatable, Sendable {
    var fontSize: Double
    var outlineWidth: Double
    var cornerRadius: Double
    var shadowDepth: Double
    var shadowBlur: Double
    var horizontalPadding: Double
    var tagHeight: Double
}

struct LegacyAppearanceProfileV3: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var themeID: AppearanceThemeID
    var palette: ThemePalette
    var geometry: ThemeGeometry
    var statusItemGeometry: LegacyStatusItemGeometryV3
    var capabilities: ThemeCapabilities
}
```

Map `shadowDepth` to both signed offsets, retain all other fields, and make v1
and v2 flow through v3 before v4. Change keys to:

```swift
static func profile(_ theme: AppearanceThemeID) -> String {
    "appearance.profile.\(theme.rawValue).v4"
}
static func legacyProfileV3(_ theme: AppearanceThemeID) -> String {
    "appearance.profile.\(theme.rawValue).v3"
}
```

Load v4, v3, v2, v1, then defaults. Persist only v4 and never remove old data.

- [ ] **Step 5: Run persistence tests**

Run `scripts/test.sh --filter AppearanceStoreTests`.

Expected: all store and migration tests pass, or the already-documented local
`Testing.framework` SDK mismatch occurs before test execution. A framework
mismatch is not treated as a source failure; main-target compilation remains
mandatory.

### Task 2: Resolve and draw independent status style

**Files:**
- Modify: `Sources/CodexLimitPeek/Appearance/AppearanceTheme.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/ThemeVisualRecipe.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/ThemeChromeViews.swift`
- Modify: `Sources/CodexLimitPeek/MenuBar/CompactStatusItemView.swift`
- Test: `Tests/CodexLimitPeekTests/Appearance/StatusItemAppearanceTests.swift`
- Test: `Tests/CodexLimitPeekTests/Appearance/AppearanceThemeTests.swift`

- [ ] **Step 1: Add failing resolver and fitter tests**

Test explicit colors with deliberately weak contrast and assert the resolved
values equal the stored opaque RGB rather than `readable(on:)`. Test `nil`
overrides retain the old readable color and outline-derived shadow. Test x/y,
opacity, and shadow color remain independent across all themes.

Add signed-shadow fitting checks:

```swift
#expect(fitted.shadowHorizontalOffset == original.shadowHorizontalOffset)
#expect(fitted.primaryTextColor == original.primaryTextColor)
#expect(fitted.weeklyTextColor == original.weeklyTextColor)
#expect(fitted.shadowColor == original.shadowColor)
#expect(fitted.shadowOpacity == original.shadowOpacity)
```

Also assert base geometry still fits an abnormally short menu bar and left/right
offsets reserve the corresponding edge.

- [ ] **Step 2: Extend the resolved contract**

Replace `shadowDepth` in `ResolvedStatusItemAppearance` with:

```swift
var shadowColor: AppearanceColor
var shadowHorizontalOffset: Double
var shadowVerticalOffset: Double
```

Resolve primary and weekly overrides separately. For `nil`, use the old
`palette.textAndOutline.readable(on: effectiveFill)` path. For explicit values,
use `clamped().withAlpha(1)` exactly. Resolve a `nil` shadow from the existing
outline color and use `statusItemStyle.shadowOpacity`.

- [ ] **Step 3: Add status-only signed shadow metrics**

Create a focused value next to `ResolvedStatusItemAppearance`:

```swift
struct StatusItemShadowMetrics: Equatable, Sendable {
    var leading: Double
    var trailing: Double
    var top: Double
    var bottom: Double
}
```

Derive directional bleed from x/y and blur, and use the same metrics for the
AppKit bounds calculation, SwiftUI preview padding, and width calculation. Do
not modify `ThemeShadowRecipe` or panel `visualInsets`.

```swift
leading = max(blur - horizontalOffset, 0)
trailing = max(blur + horizontalOffset, 0)
top = max(blur - verticalOffset, 0)
bottom = max(blur + verticalOffset, 0)
```

When resolved shadow opacity is zero, all four effective bleed values are zero
and the invisible shadow does not change status-item geometry.

Update `fitted(to:)` to retain the existing base-geometry scale/emergency path,
then fit vertical offset and blur into the remaining top/bottom budget. Never
scale horizontal offset because of menu-bar height.

- [ ] **Step 4: Update both render adapters**

In AppKit use:

```swift
shadow.shadowColor = appearance.shadowColor.nsColor.withAlphaComponent(
    CGFloat(appearance.shadowOpacity)
)
shadow.shadowOffset = NSSize(
    width: appearance.shadowHorizontalOffset,
    height: -appearance.shadowVerticalOffset
)
```

Position the tag rect using directional insets so text and shadow do not clip.
In SwiftUI render the same color/opacity and `(x, y)` values directly rather
than converting through `ThemeShadowRecipe`. Split the current single preview
text into primary and weekly segments so `weeklyTextColor` is visibly consumed;
keep the displayed ordering `81% | 1h34m | 49%` unchanged.

- [ ] **Step 5: Run focused appearance tests and a Debug build**

Run:

```sh
scripts/test.sh --filter StatusItemAppearanceTests
scripts/build-app.sh debug
```

Expected: tests pass when the local Testing runtime is compatible, and the Debug
app always builds.

### Task 3: Add editor controls and generalized color targets

**Files:**
- Modify: `Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorSupport.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorComponents.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/Editor/AppearanceColorPanelCoordinator.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/Editor/StatusItemEditorView.swift`
- Modify: `Sources/CodexLimitPeek/MenuBar/MoreOverlayViews.swift`
- Modify: `Sources/CodexLimitPeek/MenuBar/MoreOverlayPresenter.swift`
- Test: `Tests/CodexLimitPeekTests/Appearance/StatusItemEditorTests.swift`
- Test: `Tests/CodexLimitPeekTests/Appearance/AppearanceColorPanelCoordinatorTests.swift`
- Test: `Tests/CodexLimitPeekTests/Application/MoreOverlayTests.swift`

- [ ] **Step 1: Add failing metadata, binding, and color-routing tests**

Update field expectations so geometry contains font, outline, corner, x offset,
y offset, blur, padding, and height. Assert titles, ranges, steps, formatting,
and IDs such as:

```text
status-item-primary-text-color
status-item-weekly-text-color
status-item-shadow-color
status-item-shadow-opacity
status-item-shadow-horizontal-offset
status-item-shadow-vertical-offset
status-item-shadow-blur
```

Test that changing each color writes only its captured theme and status target,
and panel palette targets still preserve alpha behavior.

- [ ] **Step 2: Generalize color-panel targets**

Add:

```swift
enum AppearanceColorEditTarget: Equatable, Sendable {
    case palette(AppearanceColorToken)
    case statusItem(StatusItemColorToken)
}

enum StatusItemColorToken: String, CaseIterable, Sendable {
    case primaryText
    case weeklyText
    case shadow
}
```

Store the target in `AppearanceColorPanelEditContext`. Accept a
`showsAlpha` argument derived from the target: palette editing keeps its current
alpha behavior, while all status-item targets hide alpha and emit opaque values.
Update test doubles and callbacks to use `(theme, target, color)`.

- [ ] **Step 3: Add store helpers and editor bindings**

Add status color getter/setter/reset helpers on `AppearanceStore`, using the
captured theme rather than `selectedTheme`. Add `statusStyleBinding` for opacity
and retain `statusGeometryBinding` for x/y/blur.

In `StatusItemEditorView`, add `onOpenCustomColor`, three sections, color rows,
signed sliders, and a contrast warning when either explicit text color has a
ratio below `4.5` against `statusAppearance.fillColor.composited(over: .white)`.
The warning must not mutate the chosen color.

- [ ] **Step 4: Wire MoreOverlay to the generalized target**

Change `MoreOverlayInteractionView.onOpenCustomColor` and presenter methods to
accept `AppearanceColorEditTarget`. Panel and state-color pages wrap existing
tokens in `.palette`; status page emits `.statusItem`. Replacing the hosted root
must remain navigation-only, not occur on continuous color changes.

- [ ] **Step 5: Run focused editor and overlay tests**

Run:

```sh
scripts/test.sh --filter StatusItemEditorTests
scripts/test.sh --filter AppearanceColorPanelCoordinatorTests
scripts/test.sh --filter MoreOverlayTests
```

Expected: all focused tests pass when the Testing runtime is compatible.

### Task 4: Expose the production AppKit status item in Developer Preview

**Files:**
- Modify: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewView.swift`
- Modify: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewCoordinator.swift`
- Create: `Sources/CodexLimitPeek/DeveloperTools/DeveloperPreviewStatusItemView.swift`
- Test: `Tests/CodexLimitPeekTests/DeveloperTools/DeveloperPreviewCoordinatorTests.swift`

- [ ] **Step 1: Add failing preview projection tests**

Assert the coordinator derives fixture status text, failure-pattern state, and
resolved v4 appearance from the in-memory `AppearanceStore`. Changing theme or
style revision must change the projection without recreating a production
store.

- [ ] **Step 2: Add a Debug-only `NSViewRepresentable`**

Wrap `CompactStatusItemView`:

```swift
#if DEVELOPER_TOOLS
struct DeveloperPreviewStatusItemView: NSViewRepresentable {
    let title: String
    let weeklyTitle: String?
    let appearance: ResolvedStatusItemAppearance
    let showsFailurePattern: Bool
    let tooltip: String

    func makeNSView(context: Context) -> CompactStatusItemView {
        CompactStatusItemView()
    }

    func updateNSView(
        _ view: CompactStatusItemView,
        context: Context
    ) {
        view.update(
            title: title,
            weeklyTitle: weeklyTitle,
            appearance: appearance,
            showsFailurePattern: showsFailurePattern,
            tooltip: tooltip
        )
    }
}
#endif
```

Use the actual current `CompactStatusItemView.update` signature found in source;
the wrapper must not duplicate drawing code.

- [ ] **Step 3: Add the inspection strip**

Place the wrapped production view in a menu-bar-thickness inspection strip
outside the staged panel. Observe the in-memory appearance revision so changes
from More -> Appearance -> Status Item update it live. Give the strip stable AX
labels for Computer Use.

- [ ] **Step 4: Run Debug isolation tests and build**

Run the DeveloperTools tests and `scripts/build-app.sh debug`. Confirm the
Release build contains no developer preview wrapper declarations.

### Task 5: Full verification and Computer Use inspection

**Files:**
- Verify only; fix source/tests above if failures expose defects.

- [ ] **Step 1: Run source checks**

Run `git diff --check`, Swift formatting/parsing checks used by the repository,
and `scripts/test.sh`. If Swift Testing is blocked by the known CLT/SDK mismatch,
record the exact error and parse every test source with the compatible SDK.

- [ ] **Step 2: Build both configurations**

Use the compatible macOS 15.4 SDK and writable module caches to build Debug and
Release. Expected: both builds succeed; Release has no callable Developer Tools
entry.

- [ ] **Step 3: Operate the Debug Developer Preview with Computer Use**

Launch through `scripts/run-developer-preview.sh`, then use fresh accessibility
state after every action. Verify LOUD/BOLD/FROST and:

```text
primary and weekly colors differ visibly
shadow color and opacity update live
x = 0, y > 0 produces a pure bottom shadow
x < 0, y > 0 produces a left-bottom shadow
x > 0, y > 0 produces a right-bottom shadow
low-contrast warning appears without changing the chosen color
reset restores only the active theme
```

Close the preview and verify the exact installed formal executable returns to
its original running state. Do not install the Debug build.

- [ ] **Step 4: Report without committing**

Report changed files, actual build/test results, visual observations, and any
environment-only test blocker. Leave all changes unstaged and uncommitted for
the user to review.
