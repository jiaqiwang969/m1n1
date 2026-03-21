# Douyin Page-Size Compat Automation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a scripted Redroid workflow that applies the verified Douyin `pageSizeCompat=36` workaround and verifies it.

**Architecture:** Extend the existing host operator script with a new explicit `douyin-compat` action instead of folding Douyin-specific behavior into every restart. Keep verification generic, but surface the package compat state when Douyin is installed.

**Tech Stack:** `zsh`, `adb`, `podman`, Python `unittest`

---

### Task 1: Add failing dry-run coverage for the new action

**Files:**
- Modify: `tests/redroid/test_redroid_root_safe_107.py`
- Test: `tests/redroid/test_redroid_root_safe_107.py`

**Step 1: Write the failing test**

Add assertions that:

- `--dry-run douyin-compat` exits `0`
- dry-run output mentions `com.ss.android.ugc.aweme`
- dry-run output mentions `pageSizeCompat`
- dry-run output mentions `abx2xml`
- dry-run output mentions `xml2abx`
- dry-run output mentions rename replacement for `packages.xml`
- dry-run output mentions a restart or container recreation step

**Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v`

Expected: the new dry-run test fails because the action does not exist yet.

### Task 2: Implement the script action

**Files:**
- Modify: `redroid/scripts/redroid_root_safe_107.sh`

**Step 1: Add usage and dispatch**

Update help text and the `case` statement to include `douyin-compat`.

**Step 2: Add minimal helper functions**

Introduce helpers for:

- ensuring ADB connectivity
- reading the current Douyin `pageSizeCompat`
- applying the ABX/XML patch with a backup
- restarting after patch and re-verifying

**Step 3: Keep behavior explicit and safe**

Handle these cases separately:

- package missing
- already `36`
- needs `4 -> 36`
- unexpected value

**Step 4: Re-run the test**

Run: `python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v`

Expected: all tests pass.

### Task 3: Surface the state in `verify` and update docs

**Files:**
- Modify: `redroid/scripts/redroid_root_safe_107.sh`
- Modify: `README.md`
- Modify: `docs/guides/install-china-apps.md`

**Step 1: Extend verify output**

If Douyin is installed, print the current `pageSizeCompat` line during `verify`.

**Step 2: Update docs**

Document the new `douyin-compat` action in README and in the China-app guide.

**Step 3: Run focused verification**

Run:

```bash
python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v
zsh redroid/scripts/redroid_root_safe_107.sh --dry-run douyin-compat
zsh redroid/scripts/redroid_root_safe_107.sh --dry-run verify
```

Expected:

- unittest passes
- dry-run output shows the compat patch workflow
- verify dry-run still emits the generic runtime checks

### Task 4: Verify against the live host

**Files:**
- Modify: none

**Step 1: Run the real action**

Run:

```bash
SUDO_PASS=123123 zsh redroid/scripts/redroid_root_safe_107.sh douyin-compat
```

**Step 2: Confirm live state**

Run:

```bash
ssh wjq@192.168.1.107 "adb -s 127.0.0.1:5555 shell dumpsys package com.ss.android.ugc.aweme | grep pageSizeCompat"
ssh wjq@192.168.1.107 "adb -s 127.0.0.1:5555 shell pidof com.ss.android.ugc.aweme || true"
```

Expected:

- compat value is `36`
- no script failure

### Task 5: Commit

**Step 1: Commit the work**

```bash
git add README.md docs/guides/install-china-apps.md docs/plans/2026-03-19-douyin-pagesize-compat-design.md docs/plans/2026-03-19-douyin-pagesize-compat.md redroid/scripts/redroid_root_safe_107.sh tests/redroid/test_redroid_root_safe_107.py
git commit -m "feat: automate douyin page-size compat workaround"
```
