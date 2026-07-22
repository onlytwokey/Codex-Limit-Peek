# Background Preset Opacity Fix Design

**Status:** Approved direction, pending written-spec review

**Date:** 2026-07-22

## Context

The third background preset currently uses `#DDF3F8` with alpha `0.72` for
every theme. LOUD and BOLD render their panel shells as solid surfaces but
preserve the selected background alpha. Selecting this preset therefore lets
the underlying main panel, text, and neighboring hard shadows show through the
settings overlay, making the shadows look doubled or dirty.

FROST is different: its default background intentionally uses the same
translucent value, and its material-gradient recipe relies on that theme
semantics. The native custom color panel also intentionally exposes alpha, so
the renderer must continue to honor user-selected transparency.

## Appearance Contract

- The third background preset is fully opaque in LOUD and BOLD.
- The third background preset remains `#DDF3F8` at alpha `0.72` in FROST.
- LOUD and BOLD retain their existing solid fill, outline, and hard-shadow
  recipes.
- FROST retains its current material gradient and translucency.
- Custom colors continue to support arbitrary alpha in every theme.
- Existing saved LOUD or BOLD profiles that contain the old third preset are
  corrected automatically after upgrade.

## Considered Approaches

### 1. Theme-aware preset plus a narrow one-time migration

Pass the selected theme into the preset provider. Return an opaque third
background preset for LOUD and BOLD, while returning the existing translucent
preset for FROST. On the first launch after this change, repair only saved LOUD
and BOLD backgrounds that exactly match the retired preset value
`#DDF3F8 / 0.72`, persist the corrected profiles, and record that the migration
has completed.

This is the approved approach. It fixes both future selections and the user's
current saved state without changing custom-alpha behavior.

### 2. Make the shared third preset opaque

Changing only the shared preset is smaller, but it leaves existing saved
profiles translucent. It also makes FROST's default background stop matching
the visible preset and can move FROST away from its reference-gradient branch.
Rejected.

### 3. Force every solid panel background to alpha `1`

Normalizing alpha in the resolver would hide the problem for all existing
profiles, but it would make custom background transparency ineffective in
LOUD and BOLD even though the color picker exposes and persists alpha.
Rejected.

## Design

### Theme-aware presets

Extend `AppearanceEditorPalette.swatches` with the active theme. Only the
third `.background` entry varies by theme:

- LOUD: `AppearanceColor(hex: 0xDDF3F8)`
- BOLD: `AppearanceColor(hex: 0xDDF3F8)`
- FROST: `AppearanceColor(hex: 0xDDF3F8, alpha: 0.72)`

All other preset values remain unchanged. Both appearance-editor call sites
pass the theme whose profile they are editing. Existing exact RGBA equality
continues to control the selected checkmark.

### Existing-profile repair

Add a versioned UserDefaults migration marker. Before the marker is written,
inspect loaded profiles and update the background alpha only when all of these
conditions are true:

1. The theme is LOUD or BOLD.
2. The background exactly equals `#DDF3F8 / 0.72`.
3. The migration has not previously completed.

FROST, different RGB values, and different alpha values are untouched. Save
the repaired profiles before recording the marker, so a failed write cannot
incorrectly suppress a later retry. Once the migration has completed, users
may deliberately choose the same translucent custom color without it being
rewritten on a future launch.

No schema-version change is required because the stored profile shape does
not change.

## Verification

- Add a palette test covering the third background preset in all three themes.
- Verify the LOUD and BOLD preset resolves to a solid panel with alpha `1`.
- Add store tests proving that the exact legacy preset is repaired and remains
  repaired after reloading.
- Verify FROST and nonmatching custom translucent colors are not migrated.
- Keep the existing custom color-panel alpha tests and FROST material-gradient
  tests passing.
- Run the focused appearance tests, then `scripts/test.sh`.
- Install with `scripts/install.sh`, relaunch the installed app, and visually
  confirm the third preset in LOUD and BOLD no longer reveals underlying panel
  content while FROST remains translucent.

## Non-goals

- No changes to shadow depth, color, opacity, or geometry.
- No blanket removal of user-selected transparency.
- No changes to surface, text, action, or state-color presets.
- No redesign of the appearance editor.
