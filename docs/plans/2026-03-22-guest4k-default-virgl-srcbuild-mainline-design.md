# Guest4K Default Virgl Srcbuild Mainline Design

Date: 2026-03-22

## Problem

The `Guest4K` operator surface still treats
`localhost/redroid4k-root:alsa-hal-ranchu-exp2` as the default mainline even
though the newer source-consistent virgl path has already been validated more
strongly:

- explicit rollout succeeded live
- explicit rollback succeeded live
- runtime health showed `ro.hardware.gralloc=minigbm`
- boot completed and `surfaceflinger` stayed running
- the old fallback / DRI import / `eglCreateImageKHR` failure chain stayed absent

That leaves the workspace in an awkward state:

- the best-validated graphics path is not the default operator path
- the current docs still describe the old line as the protected mainline
- recovery knowledge depends on remembering low-visibility environment-variable
  overrides instead of a first-class operator action

## Constraints

- protect the working `Guest4K` stack on `192.168.1.107`
- keep the change narrow and reversible
- preserve a direct rollback path to the old
  `localhost/redroid4k-root:alsa-hal-ranchu-exp2` line
- do not disturb the already validated
  `virgl-srcbuild-rollout` / `virgl-srcbuild-rollback` handoff logic
- keep `IMAGE=... restart` available as an expert override
- keep existing `viewer`, `verify`, `douyin-*`, and `audio-diagnose` behavior
  unchanged

## Options

### Option A: leave the old default alone

Keep `restart` and `restart-preserve-data` on
`localhost/redroid4k-root:alsa-hal-ranchu-exp2` and continue using the
srcbuild virgl path only through the explicit rollout actions.

Why reject it:

- it keeps the operator mainline behind the verified runtime reality
- it leaves everyday usage on the older graphics line
- it turns the successful rollout/rollback work into a side path instead of the
  mainline

### Option B: promote virgl srcbuild to default and keep a script-level legacy fallback

Make `restart` and `restart-preserve-data` use
`localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322`.

Add explicit legacy actions:

- `restart-legacy`
- `restart-legacy-preserve-data`

Recommendation: choose this option.

Why:

- the best-validated path becomes the default operator surface
- the old line remains available through a direct, documented, low-risk action
- the change is narrow because only restart-action image selection changes
- fallback stays visible and easy during incident response

### Option C: promote virgl srcbuild to default but rely only on `IMAGE=...` for fallback

Why reject it:

- fallback becomes hidden knowledge
- docs cannot honestly call that a first-class rollback surface
- the protected mainline would depend on remembering a shell override pattern

## Decision

Choose Option B.

The default `Guest4K` mainline becomes the validated srcbuild virgl image:

- `DEFAULT_IMAGE=localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322`

The previous line stays as an explicit legacy fallback:

- `LEGACY_IMAGE=localhost/redroid4k-root:alsa-hal-ranchu-exp2`

## Operator Interface

Default actions:

- `restart`
- `restart-preserve-data`

These actions should use the new default image.

Legacy fallback actions:

- `restart-legacy`
- `restart-legacy-preserve-data`

These actions should use the old image directly and should not require any
environment-variable override.

Advanced override:

- keep `IMAGE=... restart` working

That override remains useful for experiments, but it is no longer the primary
rollback story.

## Implementation Shape

Refactor `restart_redroid()` so the image choice is explicit at the call site.

Recommended shape:

- `restart_redroid "<image>" "<preserve_data>"`

Callers then become small wrappers:

- `restart` -> new default image + no preserved data
- `restart-preserve-data` -> new default image + preserved data
- `restart-legacy` -> legacy image + no preserved data
- `restart-legacy-preserve-data` -> legacy image + preserved data

This keeps the functional change tightly scoped:

- one shared restart path
- one new legacy image constant
- four restart-style entrypoints with obvious semantics

The rollout and rollback functions should stay untouched.

## Logging

The restart log should print the image actually being used.

That matters because after this promotion there will be three practical startup
surfaces:

- default srcbuild virgl mainline
- explicit legacy fallback
- expert `IMAGE=...` override

Operators need a one-line confirmation of which image was actually launched.

## Testing

Add or update dry-run coverage proving:

- `restart` now launches the srcbuild virgl image by default
- `restart-preserve-data` preserves `/data` while still using the new default
  image
- `restart-legacy` launches the old `alsa-hal-ranchu-exp2` image
- `restart-legacy-preserve-data` keeps `/data` and uses the old image
- help output lists the new legacy actions
- the existing rollout/rollback dry-run expectations still pass unchanged

## Documentation

Update the main operator docs to match the new reality:

- `README.md`
- `docs/guides/guest4k-mainline-how-it-works.md`

Those docs should:

- state that the default mainline is now the srcbuild virgl image
- move the old `ANGLE + SwiftShader` line into legacy fallback / historical
  baseline language
- show the normal daily commands with `restart`
- show the incident fallback commands with `restart-legacy`

## Verification

Verification should proceed in increasing risk order:

1. focused dry-run / unit-test coverage
2. full `tests.redroid.test_redroid_guest4k_107` suite
3. live smoke on `192.168.1.107` using the new default `restart`
4. live fallback smoke using `restart-legacy`
5. final `status` confirmation to record the active runtime shape

That sequence preserves confidence while keeping the protected `Guest4K`
surface reversible at every stage.
