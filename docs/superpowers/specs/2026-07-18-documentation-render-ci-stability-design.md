# Documentation Render CI Stability Design

**Status:** Implemented and validated

**Date:** 2026-07-18

## Context

GitHub Actions run `29639874968` compiled the application and passed all 187
Swift tests. Its documentation-render step then completed one full
`DocumentationPreviewRendererTests` process successfully, including image
validation, but a second identical process exited with status 1 while running
`rendersApprovedAssets()`. GitHub reported no Swift Testing issue, PNG
validation failure, named asset mismatch, crash report, or terminating signal.

The render script currently runs the complete documentation test suite twice
in `--check` mode. Each invocation includes `rendersApprovedAssets()`, which
already calls `renderAll` twice and compares the generated PNG bytes. The full
CI test step also runs the same documentation suite before the render check.
This repeats AppKit and SwiftUI offscreen window rendering substantially more
than the verification contract requires.

The renderer, its tests, and the render script have identical Git blobs before
and after commit `682b87e`; that commit only moved Swift files into feature
directories. The failure is therefore not attributed to the directory
organization.

## Goals

- Preserve source-backed documentation rendering from production components.
- Preserve two renders and byte comparison inside
  `rendersApprovedAssets()`.
- Preserve PNG dimensions, DPI, sRGB, file-size, and README-reference checks.
- Preserve byte comparison between the generated assets and committed assets.
- Reduce redundant AppKit and SwiftUI offscreen rendering in CI.
- Make a real mismatch fail with the existing named-asset diagnostic.

## Non-goals

- No production Swift or application behavior change.
- No documentation image content or fixture change.
- No retry that can hide a deterministic failure.
- No weakening of the committed-image comparison.
- No change to the GitHub runner image or Swift toolchain.
- No third-party dependency.

## Considered Approaches

### 1. One focused render process in `--check` mode

Run only `DocumentationPreviewRendererTests.rendersApprovedAssets` once from
the shell script. The test itself continues to render twice and compare both
sets of PNG bytes. The shell then validates the generated directory and
compares it with `docs/images`.

This is the recommended approach. It retains three independent guarantees:

1. two source renders are byte-identical
2. generated files satisfy the documentation image contract
3. generated files match the committed assets

It removes repeated execution of unrelated documentation seam tests and the
second external Swift test process that failed on the GitHub runner.

### 2. Keep two external processes and retry failures

This preserves the current workload and may turn intermittent process exits
green, but it can hide real failures and adds no validation beyond the
existing internal double render plus committed-image comparison. Rejected.

### 3. Pin or replace the GitHub runner

Changing the runner or toolchain may alter the symptom, but it couples the
project to an environment change without first removing demonstrably
redundant rendering. Rejected for this fix.

## Implementation

Modify only `scripts/render-doc-previews.sh`:

- Change `render_into` to filter the single
  `DocumentationPreviewRendererTests.rendersApprovedAssets` test.
- Remove the second `CHECK_STAGING` directory and second `render_into` call
  from `--check`.
- Keep validation of the generated staging directory.
- Keep validation of committed repository images.
- Keep byte comparison between staging and `docs/images`.
- Remove now-unused cleanup state for the second staging directory.

No Swift test or renderer change is required because the selected test already
performs its own two-render determinism assertion.

## Failure Behavior

- A render-process failure remains a hard failure.
- A malformed PNG remains a hard failure with the existing validator output.
- A mismatch between the two renders remains a Swift Testing failure.
- A stale committed image remains a hard failure naming the first differing
  asset.
- Installation checks remain gated on the render check succeeding.

## Verification

The change is complete only when:

- `bash -n scripts/*.sh` passes.
- The focused filter runs exactly one test and produces all four assets.
- `scripts/render-doc-previews.sh --check` passes repeatedly from clean
  temporary output directories.
- All four generated image hashes remain unchanged locally.
- `scripts/test.sh` passes all 187 tests.
- `scripts/test-install.sh` passes.
- `scripts/build-app.sh` completes a Release build.
- `.build` is removed after local validation.
- The pushed GitHub Actions run reaches and passes the source-installation
  step.

## Residual Risk

GitHub did not provide a crash report, so the exact failing subsystem could be
AppKit, WindowServer, Swift Testing 6.1.2, or transient runner resources. This
design removes the redundant external process at the observed failure
boundary. If CI then reaches the committed-image comparison and reports a
named asset mismatch, that cross-version rendering difference will be handled
as a separate, evidence-backed issue rather than being conflated with the
process exit.
