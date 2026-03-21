# Redroid Workspace Reorganization Design

## Context

This repository started as upstream `m1n1`, but the current working state now also includes a local Redroid-on-Asahi bring-up track, host-specific operator scripts, helper tools, regression tests, and deployment notes. Those assets currently live in `tmp/` and mixed-purpose `docs/`, which makes the workspace harder to understand and easier to regress.

The verified runtime baseline on `192.168.1.107` is:

- image: `localhost/redroid16k-root:latest`
- container: `redroid16k-root-safe`
- ADB: `127.0.0.1:5555`
- VNC: `127.0.0.1:5900`
- VNC input path works
- launcher apps open normally after fixing `/system/etc/llndk.libraries.txt` and `/system/etc/sanitizer.libraries.txt` to mode `0644`

## Goals

- Keep the upstream `m1n1` tree recognizable and minimally disturbed.
- Move Redroid-specific operational assets out of `tmp/` into stable, named locations.
- Turn the root `README.md` into a workspace README that explains both `m1n1` and the local Redroid layer.
- Preserve the two Chinese reference notes, but relocate them into a guide area with clear English filenames.
- Ensure container restart does not regress the permission issue that caused app launches to bounce back to the launcher.

## Options Considered

### Option 1: Keep everything in `tmp/`

Pros:
- Minimal file churn

Cons:
- Keeps critical operational assets in a scratch area
- Obscures what is durable vs disposable
- Makes README and tests harder to structure

### Option 2: Move only scripts, leave docs/tests where they are

Pros:
- Smaller migration

Cons:
- Still leaves mixed conventions
- Does not create a clear Redroid area in the repo

### Option 3: Add a dedicated local Redroid layer while preserving upstream layout

Pros:
- Keeps upstream `m1n1` layout intact
- Makes local operator assets easy to find
- Supports future Douyin/app work cleanly

Cons:
- Requires path updates in tests and docs

Recommended: Option 3.

## Approved Design

### Repository layout

- `redroid/scripts/`
  - stable operator scripts for host bring-up and resume/debug flows
- `redroid/tools/`
  - helper Python tools used for local viewing, streaming, and ELF patching
- `docs/guides/`
  - durable Redroid usage notes and translated/renamed reference material
- `tests/redroid/`
  - Redroid-specific regression tests

Upstream `m1n1` directories such as `src/`, `proxyclient/`, `tools/`, `rust/`, and build files remain untouched.

### Documentation shape

The root `README.md` becomes the top-level entrypoint for the combined workspace:

- explain that this is an upstream `m1n1` tree plus a local Redroid track
- record the currently verified Redroid baseline
- show the new directory layout
- document the restart/status/verify/viewer workflow
- capture the permission bug and the fix
- point to guide docs and plan docs
- retain a concise upstream `m1n1` build/use section

### Runtime hardening

The main operator script should continue to pin the known-good bridge-network `/init` startup path and add a post-start permission repair step for:

- `/system/etc/llndk.libraries.txt`
- `/system/etc/sanitizer.libraries.txt`

The repair should run automatically after container creation so the app-launch regression does not reappear after restart.

### Testing

Move the regression test to `tests/redroid/` and retarget it to the new script path. The dry-run assertions should continue to pin the healthy image and command shape, and should also assert that the permission-fix logic is present in the emitted dry-run commands.

## Verification Strategy

- Dry-run the main operator script after the move.
- Run the regression test locally.
- Search the repo for stale references to the old `tmp/redroid_*` paths.
- Confirm the README points to the new paths only.

## Transition

After this reorganization lands, the next phase is application enablement: install Douyin, observe runtime dependencies and anti-virtualization issues, and extend the operator notes with a China-app-specific checklist.
