# Local-Only Documentation Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop GitHub CI from generating documentation PNGs while preserving the complete source-backed generator and its tests for local contributors.

**Architecture:** Give all documentation rasterization tests one explicit Swift Testing suite boundary. GitHub skips only that suite and retains static committed-image validation, while ordinary local tests and the focused render script continue to execute it.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, AppKit, Bash, GitHub Actions

---

## File Structure

- Modify
  `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRendererTests.swift`
  to retain only non-rasterizing renderer-contract tests.
- Create
  `Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRenderingTests.swift`
  to own the three tests that generate PNG `Data` or files.
- Modify `scripts/render-doc-previews.sh` so the local generator filters the
  new rendering suite.
- Modify `.github/workflows/tests.yml` so CI skips the rendering suite and no
  longer invokes the local render script.
- Update the approved design status and record verification results after the
  implementation passes.

### Task 1: Establish the pre-change boundary failure

- [ ] **Step 1: Run the intended CI skip before the suite exists**

Run:

```sh
scripts/test.sh --skip DocumentationPreviewRenderingTests
```

Expected: the command passes, but output still lists
`rendersApprovedAssets()`,
`productionStatusViewKeepsQuotaTextAcrossRefreshHealth()`, and
`offscreenRenderingExercisesEveryInjectedSeam()`. This demonstrates that the
new skip boundary does not exist yet.

### Task 2: Isolate documentation rasterization tests

- [ ] **Step 1: Create the rendering suite**

Create
`Tests/CodexLimitPeekTests/Documentation/DocumentationPreviewRenderingTests.swift`
with the same imports and serialized-suite declaration:

```swift
import AppKit
import Foundation
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct DocumentationPreviewRenderingTests {
}
```

Move these three complete test declarations, without changing their bodies,
from `DocumentationPreviewRendererTests` into the new struct:

```swift
func productionStatusViewKeepsQuotaTextAcrossRefreshHealth() async throws
func rendersApprovedAssets() async throws
func offscreenRenderingExercisesEveryInjectedSeam() async throws
```

Keep `DocumentationIsolationProbeError` next to the non-rendering suite because
`inMemoryDefaultsStayProcessLocal()` uses it.

- [ ] **Step 2: Point the local generator at the new suite**

In `scripts/render-doc-previews.sh`, replace:

```sh
--filter DocumentationPreviewRendererTests.rendersApprovedAssets
```

with:

```sh
--filter DocumentationPreviewRenderingTests.rendersApprovedAssets
```

- [ ] **Step 3: Verify both test boundaries**

Run:

```sh
scripts/test.sh --filter DocumentationPreviewRendererTests
scripts/test.sh --filter DocumentationPreviewRenderingTests
```

Expected: the first command runs five non-rasterizing tests; the second runs
the three rasterizing tests.

### Task 3: Make GitHub validation static-only

- [ ] **Step 1: Change the CI Swift command**

In `.github/workflows/tests.yml`, replace:

```yaml
- name: Run Swift tests
  run: scripts/test.sh
```

with:

```yaml
- name: Run Swift tests
  run: scripts/test.sh --skip DocumentationPreviewRenderingTests
```

- [ ] **Step 2: Remove the CI generator invocation**

Delete only this workflow step:

```yaml
- name: Verify documentation render determinism
  run: scripts/render-doc-previews.sh --check
```

Keep `Validate documentation images` before Swift tests and keep
`Test source installation` after them.

- [ ] **Step 3: Verify the workflow contract textually**

Run:

```sh
rg -n "render-doc-previews|DocumentationPreviewRenderingTests|validate-doc-images" .github/workflows/tests.yml
```

Expected: one skip for `DocumentationPreviewRenderingTests`, one static
validator invocation, and no `render-doc-previews` match.

### Task 4: Validate local and CI-equivalent behavior

- [ ] **Step 1: Check shell and image contracts**

Run:

```sh
bash -n scripts/*.sh
scripts/validate-doc-images.sh
```

Expected: both commands pass and the validator prints
`documentation image checks passed`.

- [ ] **Step 2: Run the CI-equivalent Swift command**

Run:

```sh
scripts/test.sh --skip DocumentationPreviewRenderingTests
```

Expected: all selected tests pass and none of the three documentation
rasterization tests appear as executed.

- [ ] **Step 3: Verify the local generator**

Run:

```sh
scripts/render-doc-previews.sh --check
```

Expected: the focused rendering test passes, all four images validate, and the
script prints `documentation preview determinism checks passed`.

- [ ] **Step 4: Run the complete local suite**

Run:

```sh
scripts/test.sh
```

Expected: the entire suite passes, including all three documentation
rasterization tests.

- [ ] **Step 5: Verify source installation**

Run:

```sh
scripts/test-install.sh
```

Expected: installation verification passes using its temporary SwiftPM build
directory.

- [ ] **Step 6: Remove generated repository build cache**

After all validation has completed, remove only the repository-local
`.build` directory and verify the worktree contains no unintended generated
files.

### Task 5: Record and publish the result

- [ ] **Step 1: Mark the design implemented**

Change the status in
`docs/superpowers/specs/2026-07-18-local-only-documentation-rendering-design.md`
from `Approved` to `Implemented and locally validated`, and append the exact
local test results.

- [ ] **Step 2: Commit the implementation**

Stage only the workflow, test split, render script, implementation plan, and
design status. Commit with:

```sh
git commit -m "ci: keep documentation rendering local"
```

- [ ] **Step 3: Push and inspect GitHub Actions**

Push `main`, open the resulting Actions run, and verify the workflow reaches
and passes `Test source installation` without a documentation render step.
