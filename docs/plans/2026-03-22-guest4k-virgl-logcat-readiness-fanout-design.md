# Guest4K Virgl Logcat Readiness Fanout Design

**Goal:** Extend the existing bounded `logcat -c` readiness retry from rollout to the remaining Guest4K virgl clone flows that still clear logcat immediately after `podman start`.

**Scope:** `virgl-srcbuild-probe`, `virgl-srcbuild-longrun`, and `virgl-fingerprint-compare` only.

**Constraints:**
- Keep `redroid16kguestprobe` mainline protected on `192.168.1.107`.
- Keep the change narrow and reversible.
- Do not change non-readiness behavior, timing windows, or restore semantics beyond replacing the noisy one-shot `logcat -c`.

**Approach:**
1. Reuse `guest_container_logcat_clear_cmd()` instead of open-coding new loops.
2. Inject the helper output into each affected guest command immediately after `podman start`.
3. Add dry-run regression tests that assert the helper-generated retry block is present and the old bare `podman exec ... /system/bin/logcat -c || true` is gone.
4. Verify with targeted tests, the full Guest4K script test suite, and shortened live probes for the three affected actions.

**Why this approach:**
- It matches the already-verified rollout fix.
- It keeps behavior consistent across the similar startup paths.
- It avoids introducing new knobs or changing the surrounding health/probe logic.
