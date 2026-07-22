# In-App Language Switching Design

**Date:** 2026-07-22  
**Status:** Approved  
**Scope:** Simplified Chinese and English application localization, immediate in-app switching, and matching bilingual README preview assets

## Context

Codex Limit Peek currently embeds Simplified Chinese user-facing strings directly across SwiftUI views, AppKit surfaces, quota presentation, notifications, accessibility metadata, errors, and speech output. The project now also has Chinese and English README documents, but both documents reference the same Chinese preview images.

The application needs a global language preference with three choices:

- Follow System
- Simplified Chinese
- English

Changing the preference must update the running application immediately without closing the active panel or requiring a relaunch. Documentation previews must also be available in both languages while continuing to reflect production UI and behavior.

## Goals

- Add a global, persistent three-state language preference.
- Update every currently visible application surface immediately after selection.
- Localize SwiftUI, AppKit, notifications, speech, errors, accessibility metadata, and date or relative-time presentation.
- Keep language independent from LOUD, BOLD, and FROST theme profiles.
- Remove localized display text from quota-source identity and business decisions.
- Preserve and migrate existing cached quota data.
- Generate Chinese and English README images from the same production components and fixed demonstration data.
- Keep documentation rendering local-only; GitHub CI validates committed assets but does not generate them.

## Non-goals

- Supporting languages other than Simplified Chinese and English in this iteration.
- Localizing README prose beyond the existing `README.md` and `README.en.md` documents.
- Changing quota thresholds, refresh behavior, appearance presets, or privacy boundaries.
- Adding direct HTTP access or third-party localization dependencies.
- Creating documentation-only UI, states, or behaviors that do not exist in production.

## Chosen Approach

Use native Swift package localization resources together with a dedicated observable `AppLanguageStore`.

This approach was selected over an ad hoc in-code dictionary because it provides a maintainable resource boundary, native locale-aware formatting, and a clearer path for future languages. System-only localization was rejected because it cannot provide the approved in-app override and immediate switching behavior.

## User Experience

### Language entry point

The More actions panel adds a compact Language row between Appearance and Quit. It uses a globe icon and shows the saved choice as its trailing value.

Selecting the row opens a compact child page containing:

- Follow System
- Simplified Chinese
- English

The active choice has a checkmark. The child page follows the existing More overlay navigation and chrome instead of introducing a separate macOS Settings window.

### Switching behavior

Selecting a language:

- keeps the More overlay open;
- preserves the active page and overlay position;
- updates the current page in place;
- updates the main quota panel, appearance pages, menu bar tooltip, accessibility text, and all other loaded UI;
- does not trigger a quota refresh;
- does not reset appearance settings or change the selected theme;
- does not dismiss the panel or pass the click through to the desktop.

Future notifications and voice announcements use the new language immediately. Any speech already in progress is stopped at the switch boundary so two languages are not mixed in one playback session. Notifications already delivered by macOS are not retroactively rewritten.

### Follow System resolution

When Follow System is selected:

- Chinese system language variants resolve to Simplified Chinese for this two-language application.
- Other system languages resolve to English.
- `NSLocale.currentLocaleDidChangeNotification` causes the running app to resolve the language again and refresh if the effective language changed.

When the user explicitly selects Simplified Chinese or English, later system-language changes do not override that selection.

## Localization Architecture

### Language model

Add a stable preference enum:

```text
AppLanguagePreference
|- system
|- simplifiedChinese
`- english
```

The preference raw value is stored in `UserDefaults`. Missing, unknown, or invalid values resolve to `system` so upgrading users retain native first-launch behavior and a corrupt preference cannot block startup.

An effective-language value contains only the two renderable languages:

```text
ResolvedAppLanguage
|- simplifiedChinese
`- english
```

Keeping the saved preference separate from its resolved value prevents a system-language change from destroying the user's Follow System choice.

### Language store

`AppLanguageStore` is a global `ObservableObject`, owned by `AppDelegate` alongside `QuotaStore` and `AppearanceStore`. It is not part of `AppearanceStore` because language is global and must not be persisted per theme.

The store is responsible for:

- reading and validating the saved preference;
- publishing the saved preference and effective language;
- persisting explicit selections;
- observing relevant system-locale changes;
- exposing the locale and localized-string resolver used by UI and non-UI code;
- publishing a revision when the effective language changes.

### Resource organization

The executable target declares native localized resources and a default localization. A single string catalog or equivalent localized resource set contains English and Simplified Chinese values for typed application keys.

English is the resource fallback language. Tests require every declared application key to have both English and Simplified Chinese values, so production fallback is defensive rather than the normal development workflow.

### SwiftUI and AppKit propagation

Every production `NSHostingController` root observes the language store and receives its effective `Locale` through the SwiftUI environment. Existing panel roots are refreshed in place; the application does not recreate or close the window solely to switch language.

AppKit-owned text, including the status-item tooltip, is refreshed from the same language revision. Non-view text does not rely on process-global system localization because a manual override must take precedence. Notifications, speech text, date formatting, errors, and accessibility strings all resolve through the same effective-language context.

## Domain and Cache Boundaries

Localized strings must never serve as business identifiers.

The current quota source display values are replaced by a stable enum such as:

```text
QuotaSource
|- appServer
|- localLog
|- localSession
|- cache
`- unavailable
```

Fallback detection and other business rules compare enum cases rather than Chinese display text. The localized source label is produced only by the presentation layer.

Cached snapshots persist stable source identifiers. Existing cache values containing legacy Chinese labels are mapped to their matching enum during decoding. Unknown legacy values use a safe fallback without discarding otherwise valid quota values.

Quota status labels, refresh failure descriptions, reset descriptions, and voice sentences become locale-aware presentation output rather than stored domain state. Compact numeric status text remains unchanged where it is already language-neutral.

## Speech, Notifications, and Formatting

- Simplified Chinese speech requests an appropriate Chinese voice.
- English speech requests an appropriate English voice.
- If the preferred voice is unavailable, the closest installed voice for the effective language is used.
- Changing language stops an active utterance before subsequent localized speech is queued.
- Future notification titles and bodies use the effective language at delivery time.
- Date and relative-time formatters use the effective locale instead of a hard-coded `zh_CN` locale.
- Existing notifications already displayed in Notification Center are outside the update boundary.

## Layout Requirements

The existing compact menu-bar and overlay character must be preserved. English translations should be concise and use existing row and page patterns. Fixed-size appearance pages may be adjusted only when necessary to prevent real English text truncation; language switching must not introduce theme-specific geometry or a new full settings window.

Both languages are visually checked at supported font-scale extremes. The active More page and its navigation state must survive the language update.

## Bilingual Documentation Rendering

The documentation image set is reorganized by explicit locale:

```text
docs/images/
|- zh-Hans/
|  |- panel-preview.png
|  |- quota-states-loud.png
|  |- refresh-states-loud.png
|  `- appearance-settings-loud.png
`- en/
   |- panel-preview.png
   |- quota-states-loud.png
   |- refresh-states-loud.png
   `- appearance-settings-loud.png
```

`README.md` references `zh-Hans`; `README.en.md` references `en`.

The renderer accepts an explicit resolved application language and never derives documentation output from the host Mac locale. Both sets use:

- the same production SwiftUI and AppKit components;
- the same LOUD, BOLD, and FROST profiles;
- the same fixed demonstration quota values;
- the same state-machine behavior;
- the same geometry and capture dimensions.

Only localized presentation changes. The English images must not be manually edited and must not add UI, labels, states, or features absent from production.

The local render command stages all eight files, validates them, and replaces the committed bilingual set atomically. A failed render or validation leaves the previous complete set intact. The repository validation checks each file's dimensions, DPI, sRGB profile, size budget, and exact README reference contract.

GitHub CI continues to skip the Swift rendering test and only validates committed static images. This preserves the existing local-only renderer boundary and avoids SDK-dependent image drift in CI.

Both READMEs also describe the three-state in-app language feature.

## Error Handling

- Invalid saved language preference: fall back to Follow System.
- Unsupported system language: resolve to English.
- Missing localized key: use English fallback and fail localization completeness tests.
- Missing preferred speech voice: select the closest installed matching-language voice.
- Unknown legacy quota source: retain valid quota data with a safe source classification.
- Documentation rendering or validation failure: do not replace any committed bilingual image.

None of these conditions may crash the menu-bar process or clear appearance preferences.

## Verification Strategy

Automated coverage includes:

- preference decoding, persistence, and invalid-value fallback;
- Follow System resolution for Chinese and non-Chinese locales;
- explicit-language precedence over system changes;
- effective-language revision publishing;
- localization-key parity across English and Simplified Chinese;
- localized quota labels, source labels, refresh descriptions, date strings, errors, notification text, accessibility text, and speech sentences;
- speech voice-language selection and cancellation on switching;
- stable quota-source business decisions in both languages;
- migration from legacy Chinese cache source values;
- More overlay language navigation, checkmark state, and page preservation;
- immediate status-item and loaded-panel refresh;
- preservation of theme, appearance profile, quota snapshot, and refresh state;
- deterministic rendering of both locale-specific documentation sets;
- bilingual image metadata, size budgets, and README reference validation.

Before handoff, run the complete project test and build scripts, install using the repository install script, restart the app, and verify all three selections in the real menu-bar UI. Visually inspect both sets of generated README images for truncation, unintended language mixing, and parity with production behavior.

## Expected Impact

The application gains a small string-resource payload and localization coordination code. This is not expected to materially increase the installed application size or runtime cost. The four additional English PNG files affect repository size, not the application bundle.

Privacy, quota acquisition, local app-server boundaries, compact menu-bar width, and theme persistence remain unchanged.
