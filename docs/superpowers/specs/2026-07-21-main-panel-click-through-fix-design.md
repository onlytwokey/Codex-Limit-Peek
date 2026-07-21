# Main Panel Click-Through Fix Design

**Status:** Approved

**Date:** 2026-07-21

## Context

The visible main quota panel is split across two AppKit windows. `panelWindow`
hosts the interactive SwiftUI content, while `panelShadowWindow` renders the
outer panel shell and shadow with mouse events disabled. The interactive
window currently has a fully clear background, and the runtime
`ThemePanelComposition` omits its own outer chrome.

As a result, clicks on the rendered quota card reach `panelWindow`, but clicks
on otherwise empty parts of the visible panel shell can pass through to the
desktop or another application. While the settings overlay is open, the first
path dismisses only the overlay, whereas the second reaches the global
outside-click monitor and dismisses both the overlay and the main panel.

## Interaction Contract

- Clicking anywhere inside the visible main panel dismisses the settings
  overlay and keeps the main panel visible.
- Clicking outside the visible main panel dismisses both the settings overlay
  and the main panel.
- Refresh, More, settings controls, scrolling, and Escape behavior remain
  unchanged.

## Considered Approaches

### 1. Give `panelWindow` a minimally nontransparent backing

Replace its fully clear AppKit background with a visually imperceptible
backing color using alpha `0.001`. This follows the existing interaction-window
pattern in `MoreOverlayPresenter` and makes the complete window rectangle
participate in Window Server hit testing without changing the rendered theme.

This is the approved approach because it fixes the event-routing boundary with
the smallest production change.

### 2. Add a full-size SwiftUI hit-test layer

Add an invisible view behind `StatusPanelView`. This keeps the change in
SwiftUI, but its behavior depends more heavily on SwiftUI-to-AppKit hit-testing
details and duplicates a pattern already solved at the AppKit window level.
Rejected.

### 3. Make `panelShadowWindow` interactive and forward events

Allow the visual shadow window to receive mouse input and forward it to the
content window. This adds window-ordering and event-forwarding complexity and
could interfere with controls. Rejected.

## Design

Keep the existing two-window architecture and visual rendering unchanged.
Configure only `panelWindow` with a calibrated color whose alpha is `0.001`.
Keep `panelShadowWindow.backgroundColor` clear and
`panelShadowWindow.ignoresMouseEvents` true.

The event flow after the change is:

1. Any point inside the main panel frame reaches `panelWindow`.
2. `MoreOverlayPresenter` classifies the click as a parent-panel click and
   closes only the settings overlay.
3. Clicks outside the main panel continue to reach the global outside-click
   monitor, which calls `AppDelegate.closePanel()`.

No dismissal-policy, view hierarchy, theme recipe, or quota behavior changes
are required.

## Verification

- Add an application lifecycle regression test asserting that the main panel
  interaction window has a nonzero but visually negligible background alpha.
- Assert that the main panel interaction window still accepts mouse events.
- Preserve the assertion that the shadow window ignores mouse events; expose
  only the minimum internal test seam needed if one does not already exist.
- Keep the existing More-overlay dismissal-policy tests passing.
- Run the focused lifecycle and More-overlay tests, followed by
  `scripts/test.sh`.

## Non-goals

- No visible color, opacity, outline, corner, or shadow change.
- No change to settings-overlay placement or sizing.
- No change to the rule for true outside clicks.
- No refactor of panel-window ownership.
