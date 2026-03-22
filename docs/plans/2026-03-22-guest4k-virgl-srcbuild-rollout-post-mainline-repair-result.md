# Guest4K Virgl Srcbuild Rollout Post-Mainline Repair Result

Date: 2026-03-22

## Summary

The explicit `virgl-srcbuild-rollout` workflow was broken after the srcbuild
virgl image became the default `Guest4K` mainline.

The immediate blocker was no longer the earlier non-blocking stderr loose end.
It was a real port-ownership regression:

- rollout still stopped only the preserved virgl control container
- the real standard-path owner was now `redroid16kguestprobe`
- rollout therefore failed with `listen tcp4 :5555: bind: address already in use`

The repair kept the preserved virgl control container as the clone source, but
shifted handoff and restore to the current standard mainline container:

- rollout prechecks `redroid16kguestprobe`
- rollout stops `redroid16kguestprobe` before starting the rollout container
- auto-restore restarts `redroid16kguestprobe`
- explicit rollback restarts `redroid16kguestprobe`

## Local Verification

Command:

```bash
python3 -m unittest tests.redroid.test_redroid_guest4k_107
```

Result:

```text
Ran 48 tests in 1.580s

OK
```

## Live Evidence

### 1. Reproduced blocker before the fix

The pre-fix live rollout failed with:

```text
Error: unable to start container "...": cannot listen on the TCP port: listen tcp4 :5555: bind: address already in use
```

That confirmed the post-mainline regression was a real standard-port ownership
problem.

### 2. Live rollout after the fix

Command:

```bash
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh virgl-srcbuild-rollout
```

Key evidence:

```text
ROLLOUT_CLONED localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322|redroid16kguestprobe-virgl-renderable-gralloc4trace-data
ROLLOUT_STARTED running|localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322
ADB_READY 127.0.0.1:5556 device
ROLLOUT_HEALTH_BEGIN
ro.hardware.gralloc=minigbm
sys.boot_completed=1
init.svc.surfaceflinger=running
ROLLOUT_HEALTH_END
ROLLOUT_ACTIVE redroid16kguestprobe-virgl-renderable-srcbuildrollout
```

Interpretation:

- the port-bind collision is gone
- rollout again reaches the intended virgl health gate

### 3. Live rollback after the fix

Command:

```bash
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh virgl-srcbuild-rollback
```

Key evidence:

```text
ROLLBACK_BEGIN
ROLLBACK_RESTORED running|localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322
```

This confirms rollback now restores the current standard mainline container.

### 4. Post-rollback health confirmation

Immediate `verify` right after rollback still raced once on ADB readiness:

```text
Timed out waiting for adb device state on 127.0.0.1:5556; last_state=unknown
```

After a short settle window, verification returned to green.

Commands:

```bash
sleep 10
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh verify
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh status
```

Key evidence:

```text
guest-ssh-ok
ADB_READY 127.0.0.1:5556 device
1
RFB 003.008
redroid16kguestprobe                                    Up About a minute
redroid16kguestprobe-virgl-renderable-srcbuildrollout   Exited
```

## Residual Loose End

The older stderr line still appears during live rollout:

```text
exec: No such file or directory
```

It no longer blocks rollout or rollback after this repair, but it remains the
next narrow diagnostic cleanup if we keep iterating on the explicit virgl
operator path.
