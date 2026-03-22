# Guest4K Restart Noise Cleanup Result

Date: 2026-03-22

## Summary

The approved Option B cleanup landed as planned:

- SSH transport helpers now suppress ephemeral host-key chatter with
  `UserKnownHostsFile=/dev/null`, `GlobalKnownHostsFile=/dev/null`, and
  `LogLevel=ERROR`
- `connect_adb()` now waits for `adb -s 127.0.0.1:5556 get-state` to reach
  `device` and emits a single stable ready line instead of printing
  `adb devices`

`wait_for_boot()` remains unchanged and is still the real Android plus VNC
readiness gate.

## Unit Test Evidence

Command:

```bash
python3 -m unittest tests.redroid.test_redroid_guest4k_107
```

Result:

```text
Ran 47 tests in 1.531s

OK
```

## Live Restart Evidence

Command:

```bash
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh restart
```

Observed success-path output included:

```text
[2026-03-22 16:53:19] connecting adb to 127.0.0.1:5556
ADB_READY 127.0.0.1:5556 device
[2026-03-22 16:53:33] waiting for Android boot and VNC banner on 127.0.0.1:5556
```

Observed absence:

- no `127.0.0.1:5556 offline` line from `adb devices`
- no `Permanently added ... to the list of known hosts`

## Live Verify Evidence

Command:

```bash
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh verify
```

Result included:

```text
guest-ssh-ok
ADB_READY 127.0.0.1:5556 device
1
RFB 003.008
```

This confirms the quieter transport path did not weaken the real guest health
checks.

## Remaining Noise

No known-host warning or transient ADB `offline` list was observed in the fresh
`restart` and `verify` runs above.
