# Status Item Style Controls Design

**Status:** Approved on 2026-07-22<br>
**Scope:** Independent text and shadow controls for the macOS menu-bar status item

## Decision

The status item receives a dedicated persisted style instead of continuing to
borrow every color from the panel palette. Users can configure the primary
quota text, weekly quota text, and shadow independently for each appearance
theme.

The shadow uses conventional two-dimensional offsets. Horizontal and vertical
offsets are independent signed values, so the same controls can create a pure
bottom shadow, the current right-bottom shadow, or shadows in any other
direction. Existing saved appearances migrate without losing their current
right-bottom direction.

## Goals

- Configure the primary quota and weekly quota text colors separately.
- Configure shadow color, opacity, blur, horizontal offset, and vertical
  offset separately.
- Keep the status-item controls independent from panel text and outline colors.
- Make a selected custom text color render exactly as selected.
- Preserve existing saved themes and the current default appearance during the
  profile-schema upgrade.
- Keep the real status item, its editor preview, and Developer Preview on one
  resolver and resolved-appearance contract.

## Non-Goals

- No font-family or font-weight picker.
- No additional app, preview host, or Release-only developer entry.
- No changes to quota semantics, status-item text ordering, refresh behavior,
  or panel palette behavior.
- No general-purpose layer or CSS-style shadow editor.

## Considered Approaches

### A. Dedicated status-item style — selected

Add a focused `StatusItemStyle` to `AppearanceProfile`, keep geometry in
`StatusItemGeometry`, and resolve both through `AppearanceResolver.status`.
This keeps status-item customization independent without duplicating the full
theme system.

### B. Add every field to `StatusItemGeometry` — rejected

This is a smaller initial diff, but it mixes colors and opacity into a type that
currently represents dimensions. The resulting persistence and editor APIs
would be harder to understand and extend.

### C. Create a complete status-item subtheme — rejected

A separate palette, recipe, and component hierarchy would provide maximum
future flexibility, but it duplicates too much of the existing appearance
system for this focused set of controls.

## Persisted Model

`AppearanceProfile` advances from schema v3 to v4 and contains:

```swift
struct StatusItemStyle: Codable, Equatable, Sendable {
    var primaryTextColor: AppearanceColor?
    var weeklyTextColor: AppearanceColor?
    var shadowColor: AppearanceColor?
    var shadowOpacity: Double
}
```

A `nil` color is an inherited theme value. This preserves the exact v3 behavior
for migrated profiles: text continues to use the previous readable theme color,
and the shadow continues to use the resolved outline color. Selecting a color
creates an explicit opaque override that is no longer altered by automatic
contrast substitution. The editor shows the effective inherited color and
allows the row to be restored to `跟随主题`.

`StatusItemGeometry` replaces the single diagonal `shadowDepth` with:

```swift
var shadowHorizontalOffset: Double
var shadowVerticalOffset: Double
var shadowBlur: Double
```

Editor coordinates are user-facing:

- negative horizontal values move left; positive values move right;
- negative vertical values move up; positive values move down.

The editor range is `-10...10` points for each offset, with a `0.5` point step.
The compatibility range remains wider than the editor range so persisted data
can be decoded without destructive clamping. Shadow blur retains its existing
`0...8` editor range and `0...20` compatibility range. Shadow opacity uses
`0...1` with a `0.05` step. Explicit color overrides are normalized to opaque
RGB; all shadow transparency comes from `shadowOpacity`, avoiding different
alpha-composition rules between AppKit and SwiftUI.

## Schema Migration

The store writes `appearance.profile.<theme>.v4` and loads in this order:

1. valid v4;
2. v3;
3. v2;
4. v1;
5. the built-in theme default.

The current v3 model is frozen as `LegacyAppearanceProfileV3`. Migration keeps
the palette, panel geometry, every non-shadow status-item geometry value, and
capabilities unchanged. It initializes the three color overrides to `nil`,
initializes shadow opacity from the theme's existing visual recipe, and maps
the old diagonal depth to both new offsets:

```text
horizontal offset = old shadow depth
vertical offset   = old shadow depth
```

Because positive editor vertical values mean downward, this mapping preserves
the existing right-bottom shadow. The old v3 bytes remain intact after v4 is
saved, preserving the existing fallback behavior.

## Editor Experience

The existing status-item editor remains a compact scrolling page with its live
preview at the top. It is organized into three sections:

1. **Text** — `Primary quota` and `Weekly quota` color rows.
2. **Shadow** — color, opacity, horizontal offset, vertical offset, and blur.
3. **Geometry** — font size, outline width, corner radius, horizontal padding,
   and tag height.

The old `Shadow depth` row is removed because the two signed offset rows replace
it. The existing custom-color panel is generalized to address panel tokens or
one of the three status-item color targets. It captures both the theme and the
target when opened, so switching themes while the panel is open cannot write to
the wrong profile.

Custom text colors are displayed exactly. When either text color has weak
contrast below `4.5:1` against the current fill, the live preview shows a small
non-blocking low-contrast notice. The stored color is never silently replaced.
Inherited colors retain the existing automatic readability behavior.

All new controls have stable accessibility identifiers and concise VoiceOver
labels. Resetting the current theme resets its status-item style and geometry
without modifying the other two themes.

## Resolution and Rendering

`AppearanceResolver.status` is the only source of the final status-item style.
`ResolvedStatusItemAppearance` gains the independent shadow color and the two
offsets; its existing primary and weekly text colors are resolved separately.

Signed shadow measurement stays status-item-specific. The shared
`ThemeShadowRecipe` and its right-bottom `visualInsets` continue serving panel
chrome unchanged. A focused status-item shadow metrics helper derives leading,
trailing, top, and bottom bleed from signed offsets and blur for the AppKit
status item and the SwiftUI preview.

The two rendering adapters consume only resolved values:

- AppKit `CompactStatusItemView` maps editor coordinates to
  `NSShadow.shadowOffset(width: x, height: -y)` because AppKit's positive y-axis
  points upward.
- The SwiftUI status preview uses `(x: x, y: y)` because SwiftUI shadow offsets
  use positive y downward.

The height fitter first retains its existing base-geometry fitting for font,
tag height, outline, corner radius, and padding. It then allocates the remaining
height budget to signed vertical shadow offset and blur, treating them as top
or bottom bleed based on the sign. Horizontal offset never gets compressed
merely because the menu bar is short. Width calculation reserves leading or
trailing space based on the horizontal sign plus blur, so a large left or right
shadow is not clipped and does not incorrectly reserve space on both sides.

If the requested vertical shadow cannot fit within the system status-bar
thickness, the resolver scales vertical offset and blur as needed to fit.
Colors, opacity, and horizontal offset remain unchanged; width is recalculated
from the fitted blur. The editor preview uses the same fitted result and
therefore shows what the real menu bar can actually display.

## Data Flow

```text
Status-item editor
  -> AppearanceStore theme profile v4
  -> AppearanceStore revision
  -> AppearanceResolver.status
  -> ResolvedStatusItemAppearance
  -> CompactStatusItemView + SwiftUI editor preview
```

No change writes into quota storage, launches the app-server, or alters the
panel's palette.

## Failure Handling

- Malformed or unsupported v4 data falls back through v3, v2, and v1.
- All numeric inputs are clamped before persistence and again at resolution.
- Invalid color components are normalized through the existing
  `AppearanceColor` validation path.
- An unsupported color-panel target is ignored instead of mutating the active
  theme; a valid callback always writes to the theme captured when it opened.
- Developer Preview continues to use isolated in-memory defaults and fixtures.

## Verification

Automated checks cover:

- independent primary, weekly, and shadow color resolution for LOUD, BOLD, and
  FROST;
- exact custom text colors and inherited readable colors;
- shadow opacity and signed two-dimensional offsets in AppKit and SwiftUI;
- v3-to-v4 migration, v4 round trips, fallback order, and per-theme reset;
- height fitting and asymmetric width reservation without color changes;
- editor control ordering, ranges, bindings, accessibility identifiers, and
  custom-color routing;
- unchanged panel resolution and quota/status text semantics;
- Debug and Release builds.

After automated checks, the same Debug-only Developer Preview is operated with
Computer Use to verify all three themes, separate text colors, a pure bottom
shadow, left-bottom and right-bottom shadows, low-contrast feedback, and reset.
For this purpose, Developer Preview gains a status-item inspection strip that
embeds the production `CompactStatusItemView` through a Debug-only
`NSViewRepresentable`. It receives the same resolved appearance and fixture
text as the real menu-bar item; the existing SwiftUI editor thumbnail remains a
secondary adapter check. The installed production app is not overwritten
during this inspection.
