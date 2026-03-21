# Guest4K Douyin Ops Design

## Scope

Add a minimal, repeatable Douyin operator surface to the current Guest4K script:

- install APK onto the Guest4K runtime
- start Douyin with a deterministic activity launch
- collect a compact runtime diagnosis surface for app state, audio state, and recent logs

Target script:

- [`redroid/scripts/redroid_guest4k_107.sh`](/Users/jqwang/25-红手指手机/m1n1/redroid/scripts/redroid_guest4k_107.sh)

This change does not migrate the older direct-host-only `douyin-compat` or `douyin-libtnet-*` workflows yet.

## Options Considered

### Option A: Add light Guest4K actions for install/start/diagnose

Pros:

- smallest useful operator surface
- matches the current verified Guest4K mainline
- does not drag old 16K-specific patching assumptions into the 4K guest path

Cons:

- does not yet replace the old `libtnet` forensic tooling

### Option B: Immediately port all direct-host Douyin helpers

Pros:

- one script owns everything

Cons:

- high risk of mixing 16K direct-host assumptions into the Guest4K path
- more surface area than needed for the current next step

### Option C: Keep Douyin handling as docs-only manual commands

Pros:

- no code change

Cons:

- repeated manual drift
- harder to reproduce later

## Decision

Use Option A.

The current need is operational repeatability on Guest4K, not another round of broad helper migration.

## Intended Actions

- `douyin-install`
  - optionally stage a local APK onto host `107`
  - install it through Guest4K ADB
- `douyin-start`
  - force-stop Douyin
  - launch a known activity with `am start -W`
  - print pid and top activity surface
- `douyin-diagnose`
  - print package path
  - print pid and top activity
  - print compact `dumpsys media.audio_flinger`
  - print compact `dumpsys audio`
  - print filtered recent `logcat`
  - print host PipeWire sink-input surface for QEMU audio

## Validation

Validation should include:

1. dry-run tests for the three new actions
2. full `tests/redroid/test_redroid_guest4k_107.py` pass
3. real Guest4K checks for:
   - `douyin-start`
   - `douyin-diagnose`
