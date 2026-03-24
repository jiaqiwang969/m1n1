# Guest4K Phone Persona Stage 1 Evidence

## Scope

This note captures the live evidence collected on `2026-03-24` for the current
`Guest4K` mainline script:

- `redroid/scripts/redroid_guest4k_107.sh`

It also records the two real runtime bugs found while validating Stage 1 on the
live host `wjq@192.168.1.107`.

## Commands Run

Baseline runtime:

```bash
SUDO_PASS=123123 zsh redroid/scripts/redroid_guest4k_107.sh restart-preserve-data
SUDO_PASS=123123 zsh redroid/scripts/redroid_guest4k_107.sh verify
```

Phone persona runtime:

```bash
SUDO_PASS=123123 zsh redroid/scripts/redroid_guest4k_107.sh phone-mode
```

Device-name persistence probe:

```bash
ssh wjq@192.168.1.107 \
  "adb -s 127.0.0.1:5556 shell settings get global device_name; \
   adb -s 127.0.0.1:5556 shell settings list global | grep -i device_name || true"
```

## Live Baseline Verify

Observed after the `restart-preserve-data` fix:

- `runtime mode`: `baseline`
- `ro.product.brand=redroid`
- `ro.product.manufacturer=redroid`
- `ro.product.model=redroid16_arm64_only_4k`
- `ro.product.device=redroid_arm64_only_4k`
- `ro.build.fingerprint=redroid/redroid_arm64_only_4k/redroid_arm64_only_4k:16/BP2A.250605.031.A3/eng.dell:userdebug/test-keys`
- `ro.build.type=userdebug`
- `ro.build.tags=test-keys`
- `ro.debuggable=1`
- `/system/xbin/su` was visible
- `RFB 003.008` was present on `127.0.0.1:5901`

Note:

- During root-cause validation of the device-name bug, `device_name` was
  intentionally set to `Codex` as a reproduction probe.
- That persisted in `/data`, so the captured baseline `device_name` was not used
  as the comparison signal for persona shaping.

## Live Phone-Mode Verify

Observed after the final quoting fix:

- `runtime mode`: `phone-mode (china-phone-v1)`
- `ro.product.brand=Xiaomi`
- `ro.product.manufacturer=Xiaomi`
- `ro.product.model=23127PN0CC`
- `ro.product.device=fuxi`
- `ro.build.fingerprint=Xiaomi/fuxi/fuxi:16/BP2A.250605.031.A3/eng.dell:userdebug/test-keys`
- `ro.build.type=userdebug`
- `ro.build.tags=test-keys`
- `ro.debuggable=1`
- `/system/xbin/su hidden`
- `device_name=Xiaomi 13`
- `settings list global` reported `device_name=Xiaomi 13`
- `RFB 003.008` was present on `127.0.0.1:5901`

## Real Runtime Bugs Found

### 1. Baseline `restart-preserve-data` could fail before `podman run`

Symptom:

- live run failed with `Error: requires at least 1 arg(s), only received 0`

Root cause:

- baseline mode left `phone_mounts` empty
- the generated `podman run` heredoc therefore contained a backslash-continued
  graphics mount line followed by an empty line
- `podman run` terminated before reaching the image argument

Fix:

- combine `graphics_mounts` and optional `phone_mounts` into one explicit
  `runtime_mounts` block
- restore newlines explicitly so baseline and phone mode both render a valid
  mount section

Regression coverage:

- `test_restart_preserve_data_dry_run_keeps_mount_block_contiguous_before_entrypoint`

### 2. `device_name` was truncated to the first token

Symptom:

- `settings get global device_name` returned `Xiaomi`
- manual probe with `Codex Test` also returned only `Codex`

Root cause:

- `adb shell settings put global device_name 'Xiaomi 13'` did not preserve the
  space-separated value through the shell boundary
- only the first token reached `settings`

Fix:

- send one quoted command string through `adb shell`:
  `adb -s 127.0.0.1:5556 shell "settings put global device_name 'Xiaomi 13'"`

Regression coverage:

- `test_phone_mode_dry_run_sets_device_name_through_device_shell_for_space_preservation`

## Test Verification

```bash
python3 -m unittest tests.redroid.test_redroid_guest4k_107 -v
```

Result:

- `Ran 102 tests in 5.110s`
- `OK`
