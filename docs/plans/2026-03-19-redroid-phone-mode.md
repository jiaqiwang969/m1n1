# Redroid Phone-Mode Runtime Shaping Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an explicit Redroid phone-mode workflow that makes the runtime look more like a real phone by spoofing safe `ro.product.*` properties, hiding `/system/xbin/su`, and preserving stable ADB access.

**Architecture:** Keep the current `restart` action unchanged as the maintenance baseline. Add a separate `phone-mode` action that stages shaped `build.prop` files plus a replacement `system/xbin` directory on the remote host, restarts the container with bind mounts for those files, then sets `device_name` and verifies the resulting app-facing surface.

**Tech Stack:** `zsh`, `ssh`, `podman`, `adb`, Python `unittest`

---

### Task 1: Add failing dry-run coverage for phone mode

**Files:**
- Modify: `tests/redroid/test_redroid_root_safe_107.py`
- Test: `tests/redroid/test_redroid_root_safe_107.py`

**Step 1: Write the failing tests**

Add tests that assert:

- `--dry-run phone-mode` exits `0`
- dry-run output mentions `Xiaomi`
- dry-run output mentions staged `system.build.prop` and `vendor.build.prop`
- dry-run output mentions a `/system/xbin` replacement that hides `su`
- dry-run output mentions `settings put global device_name`
- `--dry-run verify` mentions phone-mode specific verification lines

**Step 2: Run the tests to verify they fail**

Run:

```bash
python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v
```

Expected:

- the new phone-mode tests fail because the action and verification surface do not exist yet

### Task 2: Add phone profile data and script helpers

**Files:**
- Create: `redroid/profiles/china-phone.env`
- Modify: `redroid/scripts/redroid_root_safe_107.sh`

**Step 1: Add profile data**

Create a small shell-style profile file that defines:

- profile name
- brand/manufacturer/model/device/name
- marketing device name

**Step 2: Load the profile in the operator script**

Source the profile file from the script and expose constants for:

- local profile path
- remote profile staging directory
- remote replacement `/system/xbin` directory

**Step 3: Add remote profile-preparation helpers**

Implement helpers that:

- export `/system/build.prop` from the image into the remote staging directory
- export `/vendor/build.prop` from the image into the remote staging directory
- apply replacements and appended overrides
- create a replacement `system_xbin/` directory without `su`
- stage trusted `adb_keys`

**Step 4: Run the tests**

Run:

```bash
python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v
```

Expected:

- new tests still fail, but now on missing action dispatch or verification output instead of missing profile data

### Task 3: Implement `phone-mode` restart flow

**Files:**
- Modify: `redroid/scripts/redroid_root_safe_107.sh`

**Step 1: Extend usage and dispatch**

Add `phone-mode` to:

- usage text
- accepted actions
- `case` dispatch

**Step 2: Teach container restart about runtime shaping**

Refactor container creation so it can run in either:

- baseline mode
- phone mode

Phone mode should add bind mounts for:

- staged `system.build.prop`
- staged `vendor.build.prop`
- replacement `system_xbin/`
- staged `adb_keys`

**Step 3: Add post-boot shaping**

After phone-mode restart:

- connect ADB
- wait for boot
- set `settings put global device_name`

**Step 4: Re-run the tests**

Run:

```bash
python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v
```

Expected:

- phone-mode dry-run tests pass

### Task 4: Extend generic verification and docs

**Files:**
- Modify: `redroid/scripts/redroid_root_safe_107.sh`
- Modify: `README.md`
- Modify: `docs/guides/install-china-apps.md`

**Step 1: Add phone-mode verification output**

Update `verify` so it prints:

- runtime mode
- key app-facing properties
- `su` visibility
- current `device_name`
- existing Douyin compat state

**Step 2: Update docs**

Document:

- what phone-mode changes
- what it deliberately does not change
- recommended workflow: baseline restart -> `douyin-compat` if needed -> `phone-mode`
- rollback path: plain `restart`

**Step 3: Run focused verification**

Run:

```bash
python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v
zsh redroid/scripts/redroid_root_safe_107.sh --dry-run phone-mode
zsh redroid/scripts/redroid_root_safe_107.sh --dry-run verify
```

Expected:

- unittest passes
- dry-run phone-mode shows profile preparation and shaped bind mounts
- dry-run verify shows the new runtime-mode checks

### Task 5: Verify against the live host

**Files:**
- Modify: none

**Step 1: Run the live action**

Run:

```bash
SUDO_PASS=123123 zsh redroid/scripts/redroid_root_safe_107.sh phone-mode
```

**Step 2: Confirm the app-facing surface**

Run:

```bash
ssh wjq@192.168.1.107 "adb -s 127.0.0.1:5555 shell 'for p in ro.product.brand ro.product.manufacturer ro.product.model ro.product.device ro.build.fingerprint ro.build.type ro.build.tags ro.debuggable; do printf \"%s=\" \"$p\"; getprop \"$p\"; done; ls -l /system/xbin/su 2>/dev/null || echo su-hidden; settings get global device_name'"
```

Expected:

- the key properties no longer say `redroid`
- build type/tags may still be `userdebug` and `test-keys`
- `ro.debuggable` may still be `1`
- `/system/xbin/su` is hidden
- `device_name` is phone-like, though the framework may normalize it

**Step 3: Confirm Douyin still reaches its current flow**

Run:

```bash
ssh wjq@192.168.1.107 "adb -s 127.0.0.1:5555 shell dumpsys activity top | grep -E 'ACTIVITY|TASK|Resumed' | head -20"
```

Expected:

- Douyin can still be launched through its privacy-guide / home-ui path, even if later runtime crashes remain

### Task 6: Commit

**Step 1: Commit the work**

```bash
git add README.md docs/guides/install-china-apps.md docs/plans/2026-03-19-redroid-phone-mode-design.md docs/plans/2026-03-19-redroid-phone-mode.md redroid/profiles/china-phone.env redroid/scripts/redroid_root_safe_107.sh tests/redroid/test_redroid_root_safe_107.py
git commit -m "feat: add redroid phone mode for china apps"
```
