# Guest4K Restart Noise Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove misleading normal-case `offline` and `known_hosts` noise from the Guest4K restart path without weakening the actual readiness checks.

**Architecture:** Keep the current `restart` and `verify` flow intact, but tighten two helper layers. SSH transports will suppress ephemeral host-key chatter with explicit SSH options, and `connect_adb()` will become a bounded transport-readiness loop that waits for `device` instead of printing transient `adb devices` output. `wait_for_boot()` remains the real Android/VNC health gate.

**Tech Stack:** zsh operator script, Python `unittest`, remote ssh/scp, adb over forwarded TCP

---

### Task 1: Lock the new operator contract in tests

**Files:**
- Modify: `tests/redroid/test_redroid_guest4k_107.py`
- Test: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Write the failing tests**

Add coverage that:

- dry-run `restart` shows `LogLevel=ERROR` in the guest SSH transport
- dry-run `restart` uses `adb -s 127.0.0.1:5556 get-state`
- dry-run `restart` no longer shows the old `adb devices` success-path shape

**Step 2: Run tests to verify they fail**

Run:

```bash
python3 -m unittest \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_restart_dry_run_uses_quiet_guest_ssh_transport \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_restart_dry_run_waits_for_adb_device_state_before_reporting_ready
```

Expected: FAIL because the current script still omits `LogLevel=ERROR` and
still prints `adb devices`.

### Task 2: Implement the minimal transport cleanup

**Files:**
- Modify: `redroid/scripts/redroid_guest4k_107.sh`
- Test: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Add shared quiet SSH options**

Update the remote and guest SSH helpers to include:

- `-o UserKnownHostsFile=/dev/null`
- `-o GlobalKnownHostsFile=/dev/null`
- `-o LogLevel=ERROR`

Keep existing authentication and host targeting logic unchanged.

**Step 2: Make `connect_adb()` wait for `device`**

Change only `connect_adb()` so it:

- disconnects the current serial quietly
- polls `adb connect` and `adb -s <serial> get-state`
- exits success only when state is `device`
- prints one stable ready line on success
- prints useful failure diagnostics on timeout

Do not change `wait_for_boot()`.

**Step 3: Run the targeted tests**

Run:

```bash
python3 -m unittest \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_restart_dry_run_uses_quiet_guest_ssh_transport \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_restart_dry_run_waits_for_adb_device_state_before_reporting_ready
```

Expected: PASS

### Task 3: Verify the full operator surface and live behavior

**Files:**
- Modify: `docs/plans/2026-03-22-guest4k-restart-noise-cleanup-result.md`
- Test: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Run the full unit-test file**

Run:

```bash
python3 -m unittest tests.redroid.test_redroid_guest4k_107
```

Expected: PASS

**Step 2: Run fresh live restart and verify**

Run:

```bash
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh restart
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh verify
```

Expected:

- `restart` no longer prints the early `offline` device list
- guest SSH no longer prints `Permanently added ... to the list of known hosts`
- `verify` still reaches `guest-ssh-ok`
- `verify` still reaches `device`
- boot property remains `1`
- VNC banner remains `RFB 003.008`

**Step 3: Record results**

Create:

- `docs/plans/2026-03-22-guest4k-restart-noise-cleanup-result.md`

Capture:

- unit-test result
- live restart result
- live verify result
- any remaining noise still present after the change
