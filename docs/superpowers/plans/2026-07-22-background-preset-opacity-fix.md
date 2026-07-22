# Background Preset Opacity Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the third background preset opaque in LOUD and BOLD, preserve FROST translucency and custom alpha, and repair the retired translucent preset in existing solid-theme profiles.

**Architecture:** Make the editor preset provider theme-aware so stored RGBA values match each theme's rendering semantics. Add a versioned, one-time `UserDefaults` repair that targets only the exact retired LOUD/BOLD preset and persists repaired profiles before recording completion; leave the renderer and custom color pipeline unchanged.

**Tech Stack:** Swift 6, SwiftUI, AppKit, UserDefaults, Swift Testing, Swift Package Manager

---

### Task 1: Make the third background preset theme-aware

**Files:**
- Modify: `Tests/CodexLimitPeekTests/Appearance/AppearanceThemeTests.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorSupport.swift:207-240`
- Modify: `Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorView.swift:625-643`
- Modify: `Sources/CodexLimitPeek/Appearance/Editor/StateColorsEditorView.swift:194-212`

- [ ] **Step 1: Write the failing palette-to-resolver test**

Add this test near the other theme-default assertions:

```swift
@Test
func backgroundPresetOpacityMatchesThemeMaterialSemantics() {
    let opaqueBlue = AppearanceColor(hex: 0xDDF3F8)
    let translucentBlue = AppearanceColor(hex: 0xDDF3F8, alpha: 0.72)

    for theme in [AppearanceThemeID.loud, .bold] {
        let preset = AppearanceEditorPalette.swatches(
            for: .background,
            theme: theme
        )[2]
        #expect(preset == opaqueBlue)

        var profile = AppearanceProfile.default(for: theme)
        profile.palette.background = preset
        let resolved = AppearanceResolver.panel(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false
        )
        #expect(resolved.visuals.panelFill == .solid)
        #expect(resolved.backgroundColor.alpha == 1)
    }

    #expect(
        AppearanceEditorPalette.swatches(
            for: .background,
            theme: .frost
        )[2] == translucentBlue
    )
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
scripts/test.sh --quiet --filter AppearanceThemeTests.backgroundPresetOpacityMatchesThemeMaterialSemantics
```

Expected: compilation fails because `swatches(for:theme:)` does not exist yet,
or the LOUD/BOLD alpha assertion fails against the current shared `0.72`
preset.

- [ ] **Step 3: Implement the theme-aware preset provider**

Change the method signature and third `.background` entry exactly as follows;
the remaining switch cases keep their current arrays unchanged:

```swift
static func swatches(
    for token: AppearanceColorToken,
    theme: AppearanceThemeID
) -> [AppearanceColor] {
    let colors: [AppearanceColor]
    switch token {
    case .background:
        colors = [
            AppearanceColor(hex: 0xFFE36E),
            AppearanceColor(hex: 0xF7F3E8),
            AppearanceColor(
                hex: 0xDDF3F8,
                alpha: theme == .frost ? 0.72 : 1
            ),
            AppearanceColor(hex: 0xFFDDE5),
            AppearanceColor(hex: 0xE7DFFF)
        ]
```

Update both editor call sites with this complete call:

```swift
swatches: AppearanceEditorPalette.swatches(
    for: token,
    theme: store.selectedTheme
),
```

- [ ] **Step 4: Run the focused test and custom-alpha tests**

Run:

```bash
scripts/test.sh --quiet --filter AppearanceThemeTests.backgroundPresetOpacityMatchesThemeMaterialSemantics
scripts/test.sh --quiet --filter AppearanceColorPanelCoordinatorTests
```

Expected: both commands pass; FROST remains `0.72` and custom-alpha tests stay
green.

- [ ] **Step 5: Commit the theme-aware preset**

```bash
git add Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorSupport.swift Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorView.swift Sources/CodexLimitPeek/Appearance/Editor/StateColorsEditorView.swift Tests/CodexLimitPeekTests/Appearance/AppearanceThemeTests.swift
git commit -m "fix: keep solid theme background preset opaque"
```

### Task 2: Repair the retired preset in existing LOUD and BOLD profiles

**Files:**
- Modify: `Tests/CodexLimitPeekTests/Appearance/AppearanceStoreTests.swift`
- Modify: `Sources/CodexLimitPeek/Appearance/AppearanceStore.swift:8-18`
- Modify: `Sources/CodexLimitPeek/Appearance/AppearanceStore.swift:253-331`

- [ ] **Step 1: Write failing migration tests**

Add these tests to `AppearanceStoreTests.swift`:

```swift
@Test @MainActor
func repairsRetiredTranslucentBackgroundPresetInSolidThemes() throws {
    let defaults = isolatedDefaults()
    let retired = AppearanceColor(hex: 0xDDF3F8, alpha: 0.72)
    let replacement = AppearanceColor(hex: 0xDDF3F8)

    var loud = AppearanceProfile.default(for: .loud)
    loud.palette.background = retired
    loud.geometry.shadowDepth = 3
    var bold = AppearanceProfile.default(for: .bold)
    bold.palette.background = retired
    var frost = AppearanceProfile.default(for: .frost)
    frost.palette.background = retired

    for profile in [loud, bold, frost] {
        defaults.set(
            try JSONEncoder().encode(profile),
            forKey: AppearancePersistenceKey.profile(profile.themeID)
        )
    }

    let repaired = AppearanceStore(defaults: defaults)
    #expect(repaired.profile(for: .loud).palette.background == replacement)
    #expect(repaired.profile(for: .bold).palette.background == replacement)
    #expect(repaired.profile(for: .frost).palette.background == retired)
    #expect(repaired.profile(for: .loud).geometry.shadowDepth == 3)
    #expect(
        defaults.bool(
            forKey: AppearancePersistenceKey.opaqueBackgroundPresetMigration
        )
    )

    let restored = AppearanceStore(defaults: defaults)
    #expect(restored.profile(for: .loud).palette.background == replacement)
    #expect(restored.profile(for: .bold).palette.background == replacement)
    #expect(restored.profile(for: .frost).palette.background == retired)
}

@Test @MainActor
func backgroundPresetMigrationPreservesOtherAndLaterCustomAlpha() throws {
    let defaults = isolatedDefaults()
    var nonmatching = AppearanceProfile.default(for: .loud)
    nonmatching.palette.background = AppearanceColor(
        hex: 0xDDF3F8,
        alpha: 0.71
    )
    defaults.set(
        try JSONEncoder().encode(nonmatching),
        forKey: AppearancePersistenceKey.profile(.loud)
    )

    let firstLoad = AppearanceStore(defaults: defaults)
    #expect(
        firstLoad.profile(for: .loud).palette.background
            == nonmatching.palette.background
    )

    let deliberate = AppearanceColor(hex: 0xDDF3F8, alpha: 0.72)
    firstLoad.setColor(deliberate, for: .background, in: .loud)
    firstLoad.flushPendingSave()

    let restored = AppearanceStore(defaults: defaults)
    #expect(restored.profile(for: .loud).palette.background == deliberate)
}
```

- [ ] **Step 2: Run both tests and verify they fail**

Run:

```bash
scripts/test.sh --quiet --filter AppearanceStoreTests.repairsRetiredTranslucentBackgroundPresetInSolidThemes
scripts/test.sh --quiet --filter AppearanceStoreTests.backgroundPresetMigrationPreservesOtherAndLaterCustomAlpha
```

Expected: compilation fails because the migration key does not exist, or the
old LOUD/BOLD values remain at alpha `0.72`.

- [ ] **Step 3: Add the migration key and exact repair**

Add this key to `AppearancePersistenceKey`:

```swift
static let opaqueBackgroundPresetMigration =
    "appearance.migration.opaqueBackgroundPreset.v1"
```

Immediately after `profiles = loaded` in `AppearanceStore.init`, call:

```swift
repairRetiredTranslucentBackgroundPresetIfNeeded()
```

Add this complete private method to `AppearanceStore`:

```swift
private func repairRetiredTranslucentBackgroundPresetIfNeeded() {
    guard
        !defaults.bool(
            forKey: AppearancePersistenceKey.opaqueBackgroundPresetMigration
        )
    else {
        return
    }

    let retired = AppearanceColor(hex: 0xDDF3F8, alpha: 0.72)
    let replacement = AppearanceColor(hex: 0xDDF3F8)
    var repairedProfiles = profiles
    var encodedRepairs: [(key: String, data: Data)] = []

    for theme in [AppearanceThemeID.loud, .bold] {
        guard
            var profile = repairedProfiles[theme],
            profile.palette.background == retired
        else {
            continue
        }

        profile.palette.background = replacement
        let validated = profile.validated(for: theme)
        guard let data = try? encoder.encode(validated) else {
            return
        }
        repairedProfiles[theme] = validated
        encodedRepairs.append(
            (
                key: AppearancePersistenceKey.profile(theme),
                data: data
            )
        )
    }

    profiles = repairedProfiles
    for repair in encodedRepairs {
        defaults.set(repair.data, forKey: repair.key)
    }
    defaults.set(
        true,
        forKey: AppearancePersistenceKey.opaqueBackgroundPresetMigration
    )
}
```

Do not modify `AppearanceResolver` or `AppearanceProfile.validated(for:)`;
those paths must continue honoring deliberately selected custom alpha.

- [ ] **Step 4: Run the focused store and theme tests**

Run:

```bash
scripts/test.sh --quiet --filter AppearanceStoreTests
scripts/test.sh --quiet --filter AppearanceThemeTests
```

Expected: all store and theme tests pass. Existing LOUD/BOLD retired presets
are persisted as opaque; FROST and post-migration custom alpha remain unchanged.

- [ ] **Step 5: Commit the compatibility repair**

```bash
git add Sources/CodexLimitPeek/Appearance/AppearanceStore.swift Tests/CodexLimitPeekTests/Appearance/AppearanceStoreTests.swift
git commit -m "fix: migrate translucent solid background preset"
```

### Task 3: Verify, install, and visually accept the fix

**Files:**
- Verify: `Sources/CodexLimitPeek/Appearance/Editor/AppearanceEditorSupport.swift`
- Verify: `Sources/CodexLimitPeek/Appearance/AppearanceStore.swift`
- Verify: `Tests/CodexLimitPeekTests/Appearance/AppearanceThemeTests.swift`
- Verify: `Tests/CodexLimitPeekTests/Appearance/AppearanceStoreTests.swift`

- [ ] **Step 1: Run formatting and full regression checks**

Run:

```bash
git diff --check
scripts/test.sh
```

Expected: `git diff --check` prints nothing and the entire test suite passes.

- [ ] **Step 2: Install and relaunch the end-user app**

Run:

```bash
scripts/install.sh
```

Expected: the release app builds in a system-temporary SwiftPM scratch
directory, replaces `/Users/lin/Applications/Codex Limit Peek.app`, launches a
new `CodexLimitPeek` process, and removes its temporary directories on exit.

- [ ] **Step 3: Verify the installed process and visual behavior**

Run:

```bash
pgrep -fl CodexLimitPeek
```

Expected: one process points to the installed app. In the panel and appearance
editor, verify:

1. LOUD and BOLD show the third background preset selected with no underlying
   panel text or shadow visible through the settings surface.
2. FROST still shows the third preset selected and retains material translucency.
3. A custom translucent background selected after migration remains translucent
   after relaunch.

- [ ] **Step 4: Confirm the repository is clean**

Run:

```bash
git status --short
git log -4 --oneline
```

Expected: the worktree is clean and the design, plan, preset, and migration
commits are the newest commits.
