# Guest4K Virgl Srcbuild Rollout Post-Mainline Repair Design

Date: 2026-03-22

## Problem

After promoting the srcbuild virgl image to the default `Guest4K` mainline,
the explicit `virgl-srcbuild-rollout` workflow no longer owned the standard
guest ports by itself.

The rollout path still only stopped and restored the preserved virgl control
container:

- `redroid16kguestprobe-virgl-renderable-gralloc4trace`

But the standard ports `5555` and `5900` are now normally owned by the current
mainline container:

- `redroid16kguestprobe`

That means rollout now fails before boot with a port-bind collision instead of
reaching the intended virgl health gate.

## Constraints

- keep the fix narrow and reversible
- do not change the default `restart` path
- keep the clone source for rollout unchanged
- preserve rollback to the current standard mainline container
- avoid deleting the current mainline container or its data

## Options

### Option A: document rollout as obsolete after mainline promotion

Pros:

- no script churn

Cons:

- leaves a previously validated operator surface broken
- conflicts with the expectation that the explicit rollout path still exists

### Option B: keep cloning from the preserved virgl control container, but handoff and restore around the current standard mainline container

Pros:

- fixes the real port-owner conflict directly
- preserves the existing clone source and rollout health gate
- keeps rollback aligned with the current mainline reality

Cons:

- rollout/rollback semantics now explicitly depend on `redroid16kguestprobe`
  being the standard-path owner

### Option C: rebuild the rollout path around fresh `podman run` recreation of the mainline container

Pros:

- can restore from scratch even if the current mainline container is missing

Cons:

- much broader and riskier than needed
- loses the current container instance as the rollback anchor

## Decision

Choose Option B.

The preserved virgl control container stays the clone source for the rollout
image, but the active standard-path owner becomes the handoff anchor:

- precheck both the preserved control container and `redroid16kguestprobe`
- stop `redroid16kguestprobe` before starting the rollout container
- on auto-restore and explicit rollback, restart `redroid16kguestprobe`
  instead of the preserved virgl control container

This directly addresses the post-promotion port conflict while keeping the
explicit rollout health-gate logic intact.

## Acceptance Criteria

- dry-run rollout shows `podman container exists redroid16kguestprobe`
- dry-run rollout shows `podman stop -t 10 redroid16kguestprobe`
- dry-run rollback shows `podman start redroid16kguestprobe`
- full `tests.redroid.test_redroid_guest4k_107` stays green
- live `virgl-srcbuild-rollout` reaches `ROLLOUT_ACTIVE`
- live `virgl-srcbuild-rollback` restores `redroid16kguestprobe`
- post-rollback `verify` returns to green after the standard container
  finishes settling
