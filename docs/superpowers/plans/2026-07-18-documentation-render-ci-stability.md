# Documentation Render CI Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove redundant external documentation-render test processes while preserving internal double-render determinism, image validation, and committed-image comparison.

**Architecture:** Keep `DocumentationPreviewRendererTests.rendersApprovedAssets` as the single source-render entry point. The shell script invokes that one test once, validates its staging directory, and compares those assets with the committed images; the Swift test continues to perform two renders and byte equality checks internally.

**Tech Stack:** Bash 3.2, Swift 6, Swift Package Manager, Swift Testing, AppKit, SwiftUI, GitHub Actions

---

### Task 1: Capture the Existing Verification Contract

**Files:**

- Verify: `scripts/render-doc-previews.sh`
- Verify: `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRendererTests.swift`
- Verify: `docs/images/*.png`

- [ ] **Step 1: Confirm the clean main checkout**

Run:

```bash
git status -sb
git branch --show-current
```

Expected: branch `main`, with only this plan document untracked.

- [ ] **Step 2: Record committed documentation image hashes**

Run:

```bash
shasum -a 256 docs/images/*.png
```

Expected:

```text
e913b899213c0ffebe713009133463bf878332342f0f12e0beb99c76673b50e1  docs/images/appearance-settings-loud.png
5d7c22738b8bbede448dd4be07c898c4d221213e271ca2957f9978047534fccc  docs/images/panel-preview.png
3c5a0396813efea55baa7314b966131aaa03f3a71d83a1f7ca0b2cf3c87617e9  docs/images/quota-states-loud.png
d6a3fe12d2a5187cd9877861eb8522a941afb7b9635285fd14e6771a6b206cf9  docs/images/refresh-states-loud.png
```

- [ ] **Step 3: Confirm the redundant execution path**

Run:

```bash
rg -n 'CHECK_STAGING|render_into|DocumentationPreviewRendererTests' \
  scripts/render-doc-previews.sh
rg -n 'renderAll\\(to:' \
  Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRendererTests.swift
```

Expected: the script owns a second staging directory and calls `render_into`
twice, while the selected Swift test already calls `renderAll` twice.

### Task 2: Implement the Focused Single-process Check

**Files:**

- Modify: `scripts/render-doc-previews.sh`

- [ ] **Step 1: Narrow the Swift test filter**

Change:

```bash
--filter DocumentationPreviewRendererTests
```

to:

```bash
--filter DocumentationPreviewRendererTests.rendersApprovedAssets
```

This excludes unrelated documentation seam tests from the render-install
entry point. They remain covered by the full `scripts/test.sh` step.

- [ ] **Step 2: Remove the second external render state**

Delete:

```bash
CHECK_STAGING=""
```

and its cleanup block:

```bash
if [[ -n "$CHECK_STAGING" && -d "$CHECK_STAGING" ]]; then
  /bin/rm -rf "$CHECK_STAGING"
fi
```

- [ ] **Step 3: Preserve the check contract with one process**

Replace the current `check_only` block with:

```bash
if (( check_only )); then
  "$ROOT_DIR/scripts/validate-doc-images.sh"
  compare_directories \
    "$STAGING" \
    "$IMAGE_DIR" \
    "committed documentation image is out of date"
  echo "documentation preview determinism checks passed"
  exit 0
fi
```

The preceding `render_into "$STAGING"` and
`validate_directory "$STAGING"` calls remain unchanged.

- [ ] **Step 4: Check the patch**

Run:

```bash
git diff --check
git diff -- scripts/render-doc-previews.sh
bash -n scripts/*.sh
```

Expected: no whitespace or shell syntax errors, and no file outside the
render script is modified by this task.

### Task 3: Verify the Focused Render Entry Point

**Files:**

- Verify: `scripts/render-doc-previews.sh`
- Verify: `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRendererTests.swift`
- Verify: `docs/images/*.png`

- [ ] **Step 1: Run the focused Swift filter into a temporary directory**

Create a system-temporary directory, then run:

```bash
CODEX_LIMIT_PEEK_DOC_PREVIEW_OUTPUT_DIR="<temporary-directory>" \
  scripts/test.sh \
  --filter DocumentationPreviewRendererTests.rendersApprovedAssets
```

Expected: exactly one Swift test passes, and four PNG assets exist in the
temporary directory.

- [ ] **Step 2: Validate the focused output**

Run:

```bash
scripts/validate-doc-images.sh "<temporary-directory>"
```

Expected: `documentation image checks passed`.

- [ ] **Step 3: Remove the temporary directory**

Delete only the exact temporary directory created in Step 1 and verify it is
absent.

### Task 4: Exercise Determinism Repeatedly

**Files:**

- Verify: `scripts/render-doc-previews.sh`
- Verify: `docs/images/*.png`

- [ ] **Step 1: Run the complete check three times**

Run sequentially:

```bash
scripts/render-doc-previews.sh --check
scripts/render-doc-previews.sh --check
scripts/render-doc-previews.sh --check
```

Expected: each run reports one passing renderer test, image checks pass, and
`documentation preview determinism checks passed`.

- [ ] **Step 2: Confirm images and working tree are unchanged**

Run:

```bash
shasum -a 256 docs/images/*.png
git status --short
```

Expected: the four hashes match Task 1. Only the render script, design status,
and current plan document may be changed.

- [ ] **Step 3: Check for temporary artifact leaks**

Run:

```bash
find "${TMPDIR:-/tmp}" -maxdepth 1 \
  \( -name 'codex-limit-peek-docs.*' \
     -o -name 'codex-limit-peek-docs-check.*' \
     -o -name 'CodexLimitPeekPreview*' \) \
  -print
find docs/images -maxdepth 1 \
  \( -name '.render-doc-previews.lock' \
     -o -name '.*.new.*' \
     -o -name '.*.rollback.*' \) \
  -print
```

Expected: no output.

### Task 5: Run the Full Local Verification Matrix

**Files:**

- Verify: all production and test Swift files
- Verify: all shell scripts

- [ ] **Step 1: Run all Swift tests**

Run:

```bash
scripts/test.sh --quiet
```

Expected: 187 tests in 17 suites pass.

- [ ] **Step 2: Test source installation**

Run:

```bash
scripts/test-install.sh
```

Expected: `source installation checks passed`.

- [ ] **Step 3: Build the Release application**

Run:

```bash
scripts/build-app.sh
```

Expected: Release build completes and creates
`build/Codex Limit Peek.app`.

- [ ] **Step 4: Run final static checks**

Run:

```bash
git diff --check
bash -n scripts/*.sh
git status -sb
```

Expected: all checks pass and the worktree contains only intended changes.

### Task 6: Finalize, Publish, and Observe CI

**Files:**

- Modify: `docs/superpowers/specs/2026-07-18-documentation-render-ci-stability-design.md`
- Stage: `scripts/render-doc-previews.sh`
- Stage: current design and implementation plan

- [ ] **Step 1: Mark the design implemented**

Change:

```text
**Status:** Approved for implementation
```

to:

```text
**Status:** Implemented and validated
```

- [ ] **Step 2: Remove the regenerated SwiftPM cache**

Resolve and verify this exact directory:

```text
/Users/lin/Applications/Codex Limit Peek Source/.build
```

Record its size, confirm `workspace-state.json` exists, remove only this
directory, and verify it is absent. Do not remove the separate ignored
`build/` application output.

- [ ] **Step 3: Commit the implementation**

Run:

```bash
git add scripts/render-doc-previews.sh \
  docs/superpowers/specs/2026-07-18-documentation-render-ci-stability-design.md \
  docs/superpowers/plans/2026-07-18-documentation-render-ci-stability.md
git commit -m "ci: stabilize documentation render verification"
```

- [ ] **Step 4: Push main without force**

Confirm `main` is ahead of `origin/main` only by the design and
implementation commits, fetch the latest remote, and run:

```bash
git push origin main:main
```

- [ ] **Step 5: Observe the resulting GitHub Actions run**

Use `gh run list` to identify the push run for the implementation commit,
then monitor it until terminal.

Expected:

- Swift tests pass.
- Documentation render determinism passes.
- Source installation checks run and pass.

If the run instead reaches the committed-image comparison and reports a named
asset mismatch, stop and diagnose that cross-version rendering issue
separately. Do not regenerate or replace committed images without evidence.
