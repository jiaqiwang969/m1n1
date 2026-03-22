# Guest4K Restart Noise Cleanup Design

Date: 2026-03-22

## Problem

The promoted `Guest4K` mainline is now functionally healthy, but the operator
surface still emits two misleading startup noises during a normal `restart` /
`verify` cycle:

- `adb devices` can briefly print `127.0.0.1:5556 offline` before the guest
  fully settles
- guest SSH can still print `Permanently added ... to the list of known hosts`
  even though this workflow intentionally disables persistent host-key storage

Neither line currently means the mainline is broken, but both make the operator
surface look less deterministic than it really is.

## Constraints

- keep changes narrow and reversible on the protected `Guest4K` mainline
- do not weaken the actual health gate
- keep failure output useful if the guest really does not become ready
- preserve dry-run visibility in unit tests

## Options

### Option A: Keep current behavior and document the noise

Pros:

- zero code churn

Cons:

- the operator surface remains noisier than the real runtime state
- repeated benign warnings make true regressions harder to spot

### Option B: Quiet startup noise at the source

Change two narrow behaviors:

- add `LogLevel=ERROR` plus null known-host files to the remote / guest SSH
  transport helpers
- make `connect_adb()` wait until `adb get-state` reaches `device`, then print
  one stable ready line instead of dumping a transient `adb devices` list

Pros:

- removes misleading normal-case output
- keeps the real readiness gate in `wait_for_boot()`
- preserves actionable failure output on timeout

Cons:

- slightly less raw early-state visibility in the success path

### Option C: Move all startup logging behind an env flag

Pros:

- maximum silence in the default path

Cons:

- over-corrects a small problem
- reduces operator visibility too aggressively

## Decision

Use Option B.

`connect_adb()` should become a bounded, quiet transport-readiness step. It
should not claim Android is booted; that remains the job of `wait_for_boot()`.
If ADB never reaches `device`, the function should still fail loudly with
useful diagnostics.

SSH helpers should stop printing host-key noise in both host and guest hops,
but should continue to avoid persistent known-host state so the workflow stays
ephemeral and repeatable.

## Acceptance Criteria

- dry-run output shows `LogLevel=ERROR` in the SSH transport used by restart
- dry-run output shows `connect_adb()` polling `adb -s <serial> get-state`
  rather than printing `adb devices`
- local unit tests pass
- a fresh live `restart` no longer prints the early `offline` device list
- a fresh live `verify` still reaches guest SSH, `device`, boot `1`, and
  `RFB 003.008`
