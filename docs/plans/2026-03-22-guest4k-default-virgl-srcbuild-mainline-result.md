# Guest4K Default Virgl Srcbuild Mainline Result

Date: 2026-03-22

## Summary

The default `Guest4K` restart path is now promoted to the validated srcbuild
virgl image:

- `localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322`

The old line remains available through explicit legacy fallback actions:

- `restart-legacy`
- `restart-legacy-preserve-data`

## Extra Live Finding

The first live `restart` after the promotion failed with:

- `Error: cannot listen on the TCP port: listen tcp4 :5555: bind: address already in use`

Root cause:

- the preserved virgl control container
  `redroid16kguestprobe-virgl-renderable-gralloc4trace` was still running on
  guest ports `5555` and `5900`
- the promoted default `restart` still tried to bind the standard ports for
  `redroid16kguestprobe`
- the original promotion changed default image selection but did not yet stop
  the preserved virgl port owners before rebinding the standard path

Fix:

- `restart_redroid()` now stops the preserved virgl rollout and control
  containers before launching the standard `redroid16kguestprobe`
- those containers are stopped, not deleted, so the explicit rollout/rollback
  surface is not removed outright

## Local Verification

Full unit-test suite:

```text
python3 -m unittest tests.redroid.test_redroid_guest4k_107
Ran 46 tests in 1.489s
OK
```

## Live Verification

### 1. Default mainline restart

Command:

```bash
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh restart
```

Key evidence:

- `restarting guest Redroid container redroid16kguestprobe with image localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322`
- `host-audio-recovered:302:120%:sink=87`

Follow-up verification:

```bash
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh verify
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh status
```

Key evidence:

- `guest-ssh-ok`
- `RFB 003.008`
- `redroid16kguestprobe                                    Up About a minute`
- `redroid16kguestprobe-virgl-renderable-gralloc4trace     Exited`

### 2. Legacy fallback restart

Command:

```bash
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh restart-legacy
```

Key evidence:

- `restarting guest Redroid container redroid16kguestprobe with image localhost/redroid4k-root:alsa-hal-ranchu-exp2`
- `host-audio-recovered:302:120%:sink=87`

Follow-up verification:

```bash
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh verify
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh status
```

Key evidence:

- `guest-ssh-ok`
- `RFB 003.008`
- `redroid16kguestprobe                                    Up About a minute`

### 3. Restore preferred default

Command:

```bash
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh restart
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh verify
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh status
```

Key evidence:

- `restarting guest Redroid container redroid16kguestprobe with image localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322`
- `guest-ssh-ok`
- `RFB 003.008`
- `redroid16kguestprobe                                    Up About a minute`

Direct container inspection after restore:

```text
IMAGE localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322|running
```

### 4. Early ADB connect noise cleanup

Command:

```bash
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh restart
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh verify
```

Key evidence from the fresh `restart`:

- `restarting guest Redroid container redroid16kguestprobe with image localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322`
- `List of devices attached`
- `127.0.0.1:5556 offline`
- the old early startup line `failed to connect to 127.0.0.1:5556` no longer appeared

Key evidence from the fresh `verify`:

- `guest-ssh-ok`
- `127.0.0.1:5556	device`
- `1`
- `RFB 003.008`

Interpretation:

- `connect_adb()` now tolerates the short guest ADB startup race without printing
  a misleading hard failure line
- the transient early state is still `offline`, but the standard health check
  converges to `device` and the guest remains healthy

## Final State

The working mainline at the end of this validation is:

- container name: `redroid16kguestprobe`
- image:
  `localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322`
- guest-visible ports active through `passt`:
  - `127.0.0.1:5556 -> 5555`
  - `127.0.0.1:5901 -> 5900`

The old `alsa-hal-ranchu-exp2` line is still reachable explicitly via the new
legacy actions, but the final restored runtime is the promoted srcbuild virgl
mainline.
