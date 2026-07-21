# English README Design

**Status:** Approved for implementation

**Date:** 2026-07-21

## Context

Codex Limit Peek currently uses `README.md` as a complete Simplified Chinese
project homepage. It documents the real quota layouts, refresh-health state
machine, appearance system, local data boundaries, installation workflow,
and source structure. Four production-backed PNGs are shared by the document
and statically validated in GitHub CI.

The project needs an English documentation entry point without replacing the
existing Chinese homepage, duplicating image assets, or implying that the
application UI itself has been localized into English.

## Considered Approaches

### 1. Keep Chinese primary and add `README.en.md`

Keep `README.md` as the default GitHub homepage, add a structurally complete
English counterpart, and place reciprocal language links at the top of both
files. Both documents share the same production-rendered images.

This is the selected approach. It matches the request to add an English
version, preserves the current default experience, and keeps language choice
explicit.

### 2. Combine both languages in `README.md`

Putting Chinese and English sections into one file avoids a second document,
but doubles the page length, weakens navigation, and makes every update harder
to review. Rejected.

### 3. Make English primary and move Chinese to `README.zh-CN.md`

This is common for internationally oriented repositories, but it changes the
existing default homepage and exceeds the request to add an English version.
Rejected for this change.

## Document Structure

`README.en.md` mirrors the complete section order of `README.md`:

1. hero and project summary
2. interface preview
3. core features
4. appearance system
5. architecture
6. privacy
7. installation
8. data sources and fallback
9. development and project structure
10. system requirements
11. FAQ
12. license, attribution, and disclaimer

The English document preserves code blocks, commands, file paths, Mermaid
node identifiers, numeric thresholds, timing behavior, and implementation
type names exactly. Prose, headings, table labels, summaries, and alt text are
translated for English readers.

## Language Navigation

Place a compact navigation line before the centered hero in both documents:

```markdown
**简体中文** | [English](README.en.md)
```

```markdown
[简体中文](README.md) | **English**
```

Each file links directly to the other with a repository-relative path. The
active language is bold and not linked.

## Translation Boundaries

- Translate documentation meaning, not sentences mechanically.
- Do not add features, compatibility claims, installation methods, or UI
  states that are absent from the Chinese source and production code.
- Keep LOUD, BOLD, FROST, Codex CLI, app-server, SwiftUI, AppKit, and source
  type names unchanged.
- Keep commands and machine-readable values unchanged.
- Translate the fixed demo values only when they are prose outside images.
- Reuse the existing four PNGs without regenerating or editing them.
- State near the interface preview that screenshots retain the current
  production UI labels; the English file translates documentation only and
  does not claim English application localization.
- Preserve the privacy distinction between local quota metadata and private
  session content.
- Preserve the distinction between quota state and refresh health.

## Image Contract

Both READMEs reference these shared assets exactly once:

- `docs/images/panel-preview.png`
- `docs/images/quota-states-loud.png`
- `docs/images/refresh-states-loud.png`
- `docs/images/appearance-settings-loud.png`

The Chinese file retains its current Chinese alt text. The English file uses
faithful English alt text and the same widths. No new image is generated.

## Static Validation

Extend `scripts/validate-doc-images.sh` so its repository contract verifies:

- both README files exist
- each has the correct reciprocal language-navigation line exactly once
- each contains its four language-specific image tags exactly once
- neither references the obsolete quota or refresh SVGs
- existing PNG dimension, DPI, sRGB, per-file size, and combined-size checks
  remain unchanged

The script remains compatible with system Bash 3.2. GitHub CI continues to
run this static validator and does not run documentation rendering.

## README Project Tree

Update the project tree in both documents to list both language files:

```text
├── README.md
├── README.en.md
```

All other tree entries remain aligned with the current repository.

## Verification

The implementation is complete when:

- both language links resolve to tracked files
- Chinese content is unchanged apart from navigation and the project tree
- English headings and section order match the Chinese document
- all four shared image references pass the extended validator
- code fences, `<details>` blocks, tables, and Mermaid syntax remain balanced
- `bash -n scripts/*.sh` passes
- `scripts/validate-doc-images.sh` passes
- `git diff --check` passes
- GitHub Actions passes without a documentation render step

## Maintenance Tradeoff

Two full documents can drift. The validator can enforce file presence,
navigation, and shared image contracts, but it cannot prove semantic
translation parity. Future feature-documentation changes must update both
files in the same commit and should compare their heading structure during
review.
