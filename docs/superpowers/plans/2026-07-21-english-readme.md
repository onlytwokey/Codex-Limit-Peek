# English README Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a complete English project homepage while keeping the Chinese README primary and enforcing shared navigation and image contracts in CI.

**Architecture:** `README.md` remains the Simplified Chinese default and links to a new structurally equivalent `README.en.md`. Both files share the four existing production-rendered PNGs; the Bash validator checks file presence, reciprocal language navigation, language-specific image tags, and the existing image metadata contract.

**Tech Stack:** Markdown, HTML image tags, Mermaid, Bash 3.2, GitHub Actions

---

## File Structure

- Modify `README.md` only for language navigation and the bilingual README
  entries in the repository tree.
- Create `README.en.md` as the complete English counterpart.
- Modify `scripts/validate-doc-images.sh` to validate both README contracts.
- Update
  `docs/superpowers/specs/2026-07-21-english-readme-design.md` with final
  verification evidence.

### Task 1: Make the bilingual contract fail first

**Files:**
- Modify: `scripts/validate-doc-images.sh`
- Test: `scripts/validate-doc-images.sh`

- [ ] **Step 1: Add a reusable README contract function**

Add this function after `check_png`:

```bash
check_readme_contract() {
  local readme="$1"
  local language_navigation="$2"
  local navigation_count
  local reference
  local reference_count
  shift 2

  [[ -f "$readme" ]] \
    || fail "missing README: $readme"

  navigation_count="$(
    count_literal_occurrences "$language_navigation" "$readme"
  )"
  [[ "$navigation_count" == "1" ]] \
    || fail \
      "README must contain exactly one language navigation: $readme"

  for reference in "$@"; do
    reference_count="$(
      count_literal_occurrences "$reference" "$readme"
    )"
    [[ "$reference_count" == "1" ]] \
      || fail \
        "README must contain exactly one image reference: $reference"
  done

  if grep -Eq '(quota-states|refresh-states)\.svg' "$readme"; then
    fail "README still references an obsolete documentation SVG: $readme"
  fi
}
```

- [ ] **Step 2: Replace the single-README repository block**

Inside `if (( check_repository_contract )); then`, define separate Chinese
and English reference arrays and call the function:

```bash
  required_chinese_references=(
    '<img src="docs/images/panel-preview.png" alt="LOUD、BOLD、FROST 三套主题的状态栏显示层与额度面板预览" width="860">'
    '<img src="docs/images/quota-states-loud.png" alt="LOUD 主题下正常、警告和危险额度状态的生产菜单栏显示层" width="860">'
    '<img src="docs/images/refresh-states-loud.png" alt="LOUD 主题下双窗口与单窗口（仅周额度示例）的实时、确认中和已确认刷新状态" width="860">'
    '<img src="docs/images/appearance-settings-loud.png" alt="LOUD 主题的基础色板、面板参数、状态栏显示层和高级状态颜色设置" width="720">'
  )
  required_english_references=(
    '<img src="docs/images/panel-preview.png" alt="LOUD, BOLD, and FROST menu bar status items and quota panel previews" width="860">'
    '<img src="docs/images/quota-states-loud.png" alt="Production menu bar status items for normal, warning, and danger quota states in the LOUD theme" width="860">'
    '<img src="docs/images/refresh-states-loud.png" alt="Live, confirming, and confirmed refresh states for dual-window and weekly-only layouts in the LOUD theme" width="860">'
    '<img src="docs/images/appearance-settings-loud.png" alt="LOUD theme settings for the base palette, panel controls, menu bar status item, and advanced state colors" width="720">'
  )

  check_readme_contract \
    "$ROOT_DIR/README.md" \
    '**简体中文** | [English](README.en.md)' \
    "${required_chinese_references[@]}"
  check_readme_contract \
    "$ROOT_DIR/README.en.md" \
    '[简体中文](README.md) | **English**' \
    "${required_english_references[@]}"
```

Keep the obsolete asset existence checks after these calls.

- [ ] **Step 3: Run the validator and observe the intended failure**

Run:

```sh
bash -n scripts/validate-doc-images.sh
scripts/validate-doc-images.sh
```

Expected: shell syntax passes; repository validation fails because the
Chinese navigation is absent or `README.en.md` does not yet exist.

### Task 2: Add the complete English document

**Files:**
- Modify: `README.md`
- Create: `README.en.md`

- [ ] **Step 1: Add reciprocal language navigation**

Insert this as the first line of `README.md`:

```markdown
**简体中文** | [English](README.en.md)
```

Start `README.en.md` with:

```markdown
[简体中文](README.md) | **English**
```

- [ ] **Step 2: Translate every section with semantic parity**

Create `README.en.md` with the same heading order, four image positions,
three theme descriptions, quota examples, fixed thresholds, retry timings,
appearance ranges, Mermaid graph, privacy boundaries, installation commands,
fallback paths, development commands, project tree, requirements, FAQ,
license, attribution, and disclaimer as `README.md`.

Preserve the exact code and data tokens:

```text
61% | 3h8m | 74%
5d22h | 69%
codex app-server --stdio
account/rateLimits/read
limit_id == "codex"
~/.codex/logs_2.sqlite
~/.codex/sessions
~/.codex/archived_sessions
```

Use the four exact English image tags from Task 1. State after the first image
that the screenshots keep current production UI labels and that the English
README does not claim English localization of the app itself.

- [ ] **Step 3: Update both project trees**

Ensure both trees include:

```text
├── README.md
├── README.en.md
```

- [ ] **Step 4: Run the bilingual validator**

Run:

```sh
scripts/validate-doc-images.sh
```

Expected: `documentation image checks passed`.

### Task 3: Check structural and reader parity

**Files:**
- Verify: `README.md`
- Verify: `README.en.md`

- [ ] **Step 1: Compare structural counts**

Run heading, image, details, code-fence, and Mermaid checks for both files:

```sh
rg -n '^#{1,3} ' README.md README.en.md
rg -c '<img src="docs/images/' README.md README.en.md
rg -c '<details>|</details>' README.md README.en.md
rg -c '^```' README.md README.en.md
rg -c '^flowchart TD$' README.md README.en.md
```

Expected: section ordering is parallel; each file has four images, balanced
details tags, an even code-fence count, and one Mermaid graph.

- [ ] **Step 2: Search for accidental unsupported claims**

Read the English file end to end and confirm it does not claim an English app
UI, direct HTTP quota access, telemetry, official OpenAI status, prebuilt app
availability, or any feature absent from the Chinese source.

- [ ] **Step 3: Check repository-relative links**

Verify each local Markdown link and HTML image source resolves to an existing
tracked path. External upstream and license links remain unchanged.

### Task 4: Validate and record the result

**Files:**
- Modify:
  `docs/superpowers/specs/2026-07-21-english-readme-design.md`
- Verify: `scripts/*.sh`

- [ ] **Step 1: Run local static verification**

Run:

```sh
bash -n scripts/*.sh
scripts/validate-doc-images.sh
git diff --check
```

Expected: all commands pass.

- [ ] **Step 2: Update the design status**

Change the design status to `Implemented and locally validated` and record
the completed static checks. Do not claim GitHub validation until the commit
has been pushed and its Actions run has completed.

- [ ] **Step 3: Commit the implementation**

Stage only the two READMEs, validator, plan, and design status. Commit with:

```sh
git commit -m "docs: add English README"
```

- [ ] **Step 4: Leave publication explicit**

Report the clean local commit and wait for explicit authorization before
pushing `main` to GitHub.
