# Bilingual Documentation Previews Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate, validate, and reference separate Simplified Chinese and English README image sets from the same production components and fixed demo state.

**Architecture:** Parameterize the local-only documentation renderer with ResolvedAppLanguage, keep documentation-only captions in a typed locale-specific copy structure, and render both locale directories in one staged transaction. Expand static validation and README contracts to cover all eight PNG files while preserving the CI rule that generation never runs on GitHub.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Testing, Bash, sips, GitHub Actions static validation

---

## Dependency and file structure

Execute this plan only after `docs/superpowers/plans/2026-07-22-app-language-switching.md` is complete and the installed app can render both resolved languages.

Create:

- `docs/images/zh-Hans/panel-preview.png`
- `docs/images/zh-Hans/quota-states-loud.png`
- `docs/images/zh-Hans/refresh-states-loud.png`
- `docs/images/zh-Hans/appearance-settings-loud.png`
- `docs/images/en/panel-preview.png`
- `docs/images/en/quota-states-loud.png`
- `docs/images/en/refresh-states-loud.png`
- `docs/images/en/appearance-settings-loud.png`

Remove after successful replacement:

- `docs/images/panel-preview.png`
- `docs/images/quota-states-loud.png`
- `docs/images/refresh-states-loud.png`
- `docs/images/appearance-settings-loud.png`

Modify:

- `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRenderer.swift`: language parameter, localized production roots, and bilingual documentation captions.
- `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRendererTests.swift`: copy and fixture parity.
- `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRenderingTests.swift`: deterministic bilingual asset generation.
- `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewSeamTests.swift`: production-component and explicit-language seams.
- `scripts/render-doc-previews.sh`: stage and atomically install eight assets.
- `scripts/validate-doc-images.sh`: validate bilingual paths, budgets, and README contracts.
- `README.md`: reference zh-Hans images and document language settings.
- `README.en.md`: reference English images and document language settings.
- GitHub workflow only if its current validation command enumerates four paths instead of calling scripts/validate-doc-images.sh without arguments.

### Task 1: Make documentation fixtures explicitly language-aware

**Files:**
- Modify: `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRenderer.swift`
- Modify: `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRendererTests.swift`
- Modify: `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewSeamTests.swift`

- [ ] **Step 1: Write failing bilingual fixture tests**

Add tests that prohibit host-locale dependence and prove data parity:

~~~swift
@Test
func documentationCopyChangesOnlyPresentationLanguage() {
    let chinese = DocumentationPreviewCopy(
        language: .simplifiedChinese
    )
    let english = DocumentationPreviewCopy(
        language: .english
    )

    #expect(chinese.quotaStatesTitle == "菜单栏用量颜色")
    #expect(english.quotaStatesTitle == "Menu Bar Quota Colors")
    #expect(chinese.normalStateLabel == "额度充足")
    #expect(english.normalStateLabel == "Quota Healthy")
}

@Test
func productionPanelFixturesKeepIdenticalStateAcrossLanguages() {
    let chinese = DocumentationPreviewRenderer.panelData(
        language: .simplifiedChinese
    )
    let english = DocumentationPreviewRenderer.panelData(
        language: .english
    )

    #expect(chinese.percentText == english.percentText)
    #expect(chinese.displayRemainingPercent == english.displayRemainingPercent)
    #expect(chinese.showsSecondaryQuota == english.showsSecondaryQuota)
    #expect(chinese.primaryQuotaLabel != english.primaryQuotaLabel)
}

@Test
func rendererRequiresAnExplicitLanguage() {
    let signature:
        (ResolvedAppLanguage, URL) async throws -> Void =
        DocumentationPreviewRenderer.renderApprovedAssets
    _ = signature
}
~~~

- [ ] **Step 2: Run non-rendering documentation tests and verify failure**

~~~bash
scripts/test.sh --filter DocumentationPreviewRendererTests
scripts/test.sh --filter DocumentationPreviewSeamTests
~~~

Expected: compilation fails because DocumentationPreviewCopy and explicit-language renderer APIs do not exist.

- [ ] **Step 3: Add typed documentation-only copy**

Create DocumentationPreviewCopy in DocumentationPreviewRenderer.swift. It may switch on ResolvedAppLanguage because these headings and explanatory labels are external documentation composition, not application-bundle text:

~~~swift
struct DocumentationPreviewCopy {
    let language: ResolvedAppLanguage

    var quotaStatesTitle: String {
        switch language {
        case .simplifiedChinese:
            "菜单栏用量颜色"
        case .english:
            "Menu Bar Quota Colors"
        }
    }

    var normalStateLabel: String {
        switch language {
        case .simplifiedChinese:
            "额度充足"
        case .english:
            "Quota Healthy"
        }
    }
}
~~~

Complete the structure for every current renderer-owned Chinese heading, subheading, state label, retry explanation, panel caption, and settings caption found by:

~~~bash
rg -n '"[^"\n]*[一-龥][^"\n]*"' Tests/CodexLimitPeekTests/Documentation
~~~

Use concise English that describes the existing production behavior. Do not add a state, feature, control, timeline, or message that production source does not support.

- [ ] **Step 4: Parameterize production fixture construction**

Every fixture builder accepts ResolvedAppLanguage and creates:

~~~swift
let localization = AppLocalization(language: language)
let presentation = snapshot.presentation(
    localization: localization,
    referenceDate: fixedReferenceDate,
    timeZone: fixedTimeZone
)
~~~

Populate ThemePanelDisplayData and appearance editor roots from production localized APIs. Replace sourceName demonstration strings with stable QuotaSource cases.

Never use Locale.current, Locale.preferredLanguages, AppLanguageStore(), or UserDefaults.standard in documentation rendering.

- [ ] **Step 5: Pass language through every renderer entry point**

The public test seam is:

~~~swift
static func renderApprovedAssets(
    language: ResolvedAppLanguage,
    to outputDirectory: URL
) async throws
~~~

Every lower-level panel, quota-state, refresh-state, settings-cell, SwiftUI hosting, and image-composition function receives the explicit language, AppLocalization, or DocumentationPreviewCopy. No lower-level function silently defaults to Chinese.

- [ ] **Step 6: Run renderer and seam tests**

~~~bash
scripts/test.sh --filter DocumentationPreviewRendererTests
scripts/test.sh --filter DocumentationPreviewSeamTests
~~~

Expected: tests pass, numeric and state fixtures match across languages, and presentation strings differ where expected.

- [ ] **Step 7: Commit renderer parameterization**

~~~bash
git add Tests/CodexLimitPeekTests/Documentation
git commit -m "test: parameterize documentation previews by language"
~~~

### Task 2: Render both locale sets deterministically

**Files:**
- Modify: `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRenderingTests.swift`
- Modify: `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRenderer.swift`

- [ ] **Step 1: Change the approved-assets test to require locale directories**

Use the existing CODEX_LIMIT_PEEK_DOC_PREVIEW_OUTPUT_DIR as a staging root:

~~~swift
@Test
func rendersApprovedAssets() async throws {
    let root = try #require(
        ProcessInfo.processInfo.environment[
            "CODEX_LIMIT_PEEK_DOC_PREVIEW_OUTPUT_DIR"
        ]
    )
    let rootURL = URL(fileURLWithPath: root, isDirectory: true)

    for language in ResolvedAppLanguage.allCases {
        let localeDirectory = rootURL
            .appendingPathComponent(
                language.rawValue,
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: localeDirectory,
            withIntermediateDirectories: true
        )
        try await DocumentationPreviewRenderer
            .renderApprovedAssets(
                language: language,
                to: localeDirectory
            )
    }
}
~~~

- [ ] **Step 2: Expand deterministic tests**

For each approved asset, render Chinese twice and English twice and compare PNG data within the same language. Also assert Chinese and English settings or quota PNG data are not identical:

~~~swift
#expect(firstChinese == secondChinese)
#expect(firstEnglish == secondEnglish)
#expect(firstChinese != firstEnglish)
~~~

Do not assert pixel differences between languages for a file that contains no localized pixels; all four approved assets currently contain localized UI or documentation text.

- [ ] **Step 3: Run explicit rendering into a temporary directory**

~~~bash
render_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-limit-peek-bilingual-test.XXXXXX")"
CODEX_LIMIT_PEEK_DOC_PREVIEW_OUTPUT_DIR="$render_root" scripts/test.sh --filter DocumentationPreviewRenderingTests.rendersApprovedAssets
find "$render_root" -maxdepth 2 -type f -name '*.png' -print | sort
~~~

Expected: exactly four PNG files under zh-Hans and four under en. Remove the explicit temporary directory after inspection.

- [ ] **Step 4: Commit rendering tests**

~~~bash
git add Tests/CodexLimitPeekTests/Documentation
git commit -m "test: render bilingual documentation assets"
~~~

### Task 3: Expand static image and README validation

**Files:**
- Modify: `scripts/validate-doc-images.sh`
- Modify: `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRendererTests.swift`

- [ ] **Step 1: Add a failing repository-contract check**

Before changing validation, run:

~~~bash
scripts/validate-doc-images.sh
~~~

Expected after the README paths are moved to locale directories: the old validator reports missing root-level assets.

- [ ] **Step 2: Define the bilingual asset matrix**

Use:

~~~bash
LOCALES=("zh-Hans" "en")
ASSETS=(
  "panel-preview.png"
  "quota-states-loud.png"
  "refresh-states-loud.png"
  "appearance-settings-loud.png"
)
WIDTHS=(2400 1840 1840 1440)
HEIGHTS=(900 720 1350 2400)
~~~

With no arguments, build eight PATHS by locale and asset. With one argument, treat it as a staging root containing both locale directories. Remove the four-positional-path mode because it cannot represent the approved bilingual set atomically.

- [ ] **Step 3: Apply per-file and aggregate budgets**

Keep the 3 MiB per-file cap. Replace the single 5 MiB aggregate cap with:

~~~bash
MAX_LOCALE_BYTES=$((5 * 1024 * 1024))
MAX_TOTAL_BYTES=$((10 * 1024 * 1024))
~~~

Track each locale subtotal and the eight-file total. Run the existing PNG, dimension, DPI, and sRGB checks on every file.

- [ ] **Step 4: Update exact README reference contracts**

Require Chinese references under docs/images/zh-Hans and English references under docs/images/en:

~~~html
<img src="docs/images/zh-Hans/panel-preview.png" alt="LOUD、BOLD、FROST 三套主题的状态栏显示层与额度面板预览" width="860">
<img src="docs/images/en/panel-preview.png" alt="LOUD, BOLD, and FROST menu bar status items and quota panel previews" width="860">
~~~

Repeat for quota-states-loud.png, refresh-states-loud.png, and appearance-settings-loud.png using the existing alt text and widths.

Also fail when either README references docs/images/<asset> without a locale directory, and fail when any old root-level approved PNG remains.

- [ ] **Step 5: Test validator behavior with a staged bilingual tree**

~~~bash
stage="$(mktemp -d "${TMPDIR:-/tmp}/codex-limit-peek-validate.XXXXXX")"
mkdir -p "$stage/zh-Hans" "$stage/en"
cp docs/images/*.png "$stage/zh-Hans/"
cp docs/images/*.png "$stage/en/"
scripts/validate-doc-images.sh "$stage"
~~~

Expected before real regeneration: validation passes metadata and dimensions for the copied fixture tree. Remove the temporary stage afterward.

- [ ] **Step 6: Commit validation changes**

~~~bash
git add scripts/validate-doc-images.sh Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRendererTests.swift
git commit -m "test: validate bilingual documentation images"
~~~

### Task 4: Make local installation of all eight images atomic

**Files:**
- Modify: `scripts/render-doc-previews.sh`

- [ ] **Step 1: Extend the script's render and compare loops**

Use the same LOCALES and ASSETS arrays as the validator. render_into produces both subdirectories through DocumentationPreviewRenderingTests. compare_directories compares:

~~~bash
for locale in "${LOCALES[@]}"; do
  for asset in "${ASSETS[@]}"; do
    cmp -s "$left/$locale/$asset" "$right/$locale/$asset" || {
      echo "$mismatch_message: $locale/$asset" >&2
      return 1
    }
  done
done
~~~

- [ ] **Step 2: Stage rollback and new paths for eight targets**

Create docs/images/zh-Hans and docs/images/en before taking the lock. For each locale/asset pair:

1. Resolve one explicit target.
2. Back up an existing regular file.
3. Reject a non-regular target.
4. Install the staged image into a same-directory .new file.
5. Record whether an original existed.

Do not use unresolved globs to move or remove target files.

- [ ] **Step 3: Validate before and after replacement**

Run:

~~~bash
scripts/validate-doc-images.sh "$STAGING"
~~~

before replacement. After all eight moves, run repository validation and compare each staged file to its installed target. Mark replacement_committed only after every check succeeds.

On interruption or failure, restore all eight prior targets and remove newly created targets for which no original existed.

- [ ] **Step 4: Preserve check-only behavior**

scripts/render-doc-previews.sh --check renders both languages to staging, validates committed repository images, and compares all eight paths. It does not write docs/images.

- [ ] **Step 5: Exercise rollback safely**

Add or reuse a shell test seam that points validation at a wrapper returning failure after staging but before replacement. Confirm checksums of all committed images remain unchanged. Do not deliberately corrupt committed targets to test rollback.

- [ ] **Step 6: Commit the local renderer script**

~~~bash
git add scripts/render-doc-previews.sh
git commit -m "build: install bilingual doc previews atomically"
~~~

### Task 5: Regenerate images and update both READMEs

**Files:**
- Create: eight locale-specific PNG files under docs/images
- Remove: four root-level approved PNG files
- Modify: `README.md`
- Modify: `README.en.md`

- [ ] **Step 1: Update README image paths**

README.md uses docs/images/zh-Hans for all four approved assets. README.en.md uses docs/images/en.

- [ ] **Step 2: Document the in-app language feature**

In the existing feature or appearance section, add concise language-matched copy.

Chinese:

~~~markdown
- 应用内可选择跟随系统、简体中文或 English，切换后无需重启。
~~~

English:

~~~markdown
- Choose Follow System, Simplified Chinese, or English in the app; changes apply without a restart.
~~~

Do not claim support for Traditional Chinese or languages other than the approved two renderable languages.

- [ ] **Step 3: Generate and atomically install both image sets**

~~~bash
scripts/render-doc-previews.sh
~~~

Expected: the script reports that bilingual documentation previews were installed and all eight targets pass validation.

- [ ] **Step 4: Remove obsolete root-level images**

After the bilingual install and README path update have passed, remove only these exact files:

~~~bash
git rm docs/images/panel-preview.png
git rm docs/images/quota-states-loud.png
git rm docs/images/refresh-states-loud.png
git rm docs/images/appearance-settings-loud.png
~~~

The locale-specific replacements are already present and validated, so this is a recoverable Git operation.

- [ ] **Step 5: Validate the repository contract**

~~~bash
scripts/validate-doc-images.sh
scripts/render-doc-previews.sh --check
~~~

Expected: static validation passes and a clean re-render is byte-identical to the committed bilingual set.

- [ ] **Step 6: Visually inspect all eight assets**

Open each PNG at full resolution and verify:

- no Chinese application text appears in en;
- no English application text appears in zh-Hans except product and theme names such as CODEX, LOUD, BOLD, and FROST;
- quota numbers, reset examples, status colors, refresh states, themes, and settings values match across languages;
- English text is not clipped, overlapped, or reduced below the production typography rules;
- documentation headings describe only behaviors present in source;
- the application UI inside images is produced by production components.

- [ ] **Step 7: Commit README and generated assets**

~~~bash
git add README.md README.en.md docs/images/zh-Hans docs/images/en
git add -u docs/images
git commit -m "docs: add bilingual application previews"
~~~

### Task 6: Confirm CI remains validation-only

**Files:**
- Inspect: `.github/workflows/*.yml`
- Modify only the workflow that invokes documentation validation if required

- [ ] **Step 1: Inspect workflow commands**

~~~bash
rg -n "DocumentationPreviewRenderingTests|render-doc-previews|validate-doc-images" .github/workflows
~~~

Expected: CI calls scripts/validate-doc-images.sh and excludes DocumentationPreviewRenderingTests from the normal Swift test run.

- [ ] **Step 2: Update only stale explicit paths**

If the workflow calls the validator with four explicit root-level PNG paths, replace that command with:

~~~bash
scripts/validate-doc-images.sh
~~~

If it already uses the no-argument repository contract, make no workflow change.

Never add scripts/render-doc-previews.sh or DocumentationPreviewRenderingTests to a GitHub Actions job.

- [ ] **Step 3: Run the same local checks as CI**

~~~bash
scripts/test.sh
scripts/validate-doc-images.sh
~~~

Expected: the full non-rendering test suite and bilingual static image contract pass.

- [ ] **Step 4: Commit a workflow adjustment only when necessary**

~~~bash
git add .github/workflows
git commit -m "ci: validate bilingual documentation assets"
~~~

Do not create this commit if no workflow file changed.

### Task 7: Final repository verification

**Files:**
- No planned source changes

- [ ] **Step 1: Verify README references resolve**

~~~bash
for readme in README.md README.en.md; do
  rg -o 'docs/images/[^"]+\.png' "$readme"
done
~~~

Expected: four zh-Hans paths in README.md and four en paths in README.en.md.

- [ ] **Step 2: Verify exact asset inventory**

~~~bash
find docs/images -maxdepth 2 -type f -name '*.png' -print | sort
~~~

Expected: exactly the eight approved locale-specific PNG files and no root-level approved PNG.

- [ ] **Step 3: Run final deterministic and static checks**

~~~bash
scripts/validate-doc-images.sh
scripts/render-doc-previews.sh --check
git diff --check
git status --short
~~~

Expected: both documentation commands pass, no whitespace errors are reported, and status contains no renderer lock, rollback, staging, .build, or temporary files.

- [ ] **Step 4: Inspect final commit scope**

~~~bash
git log --oneline --decorate -12
git diff --stat origin/main...HEAD
~~~

Expected: application localization commits precede bilingual documentation commits, and unrelated user work is not included in any language-feature commit.
