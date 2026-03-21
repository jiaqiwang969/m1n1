# Guest4K Douyin Ops Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a minimal Douyin install/start/diagnose workflow to the current Guest4K operator script.

**Architecture:** Extend the existing Guest4K script with three narrow actions that reuse the current SSH, guest SSH, and ADB helpers. Keep the actions observational and operational; do not port old direct-host-specific `libtnet` mutation flows yet.

**Tech Stack:** zsh, adb, ssh/scp, pytest/unittest dry-run regression tests, Markdown docs

---

### Task 1: Lock the new Guest4K Douyin actions in tests

**Files:**
- Modify: `tests/redroid/test_redroid_guest4k_107.py`
- Test: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Write failing dry-run tests**

Add tests for:

- `douyin-install`
- `douyin-start`
- `douyin-diagnose`

**Step 2: Run tests to verify they fail**

Run:

```bash
python3 -m pytest tests/redroid/test_redroid_guest4k_107.py -k 'douyin_install or douyin_start or douyin_diagnose' -v
```

Expected: FAIL because the actions do not exist yet.

**Step 3: Write minimal implementation**

Add the three actions to `redroid/scripts/redroid_guest4k_107.sh`.

**Step 4: Run tests to verify they pass**

Run:

```bash
python3 -m pytest tests/redroid/test_redroid_guest4k_107.py -k 'douyin_install or douyin_start or douyin_diagnose' -v
```

Expected: PASS

### Task 2: Sync the current docs

**Files:**
- Modify: `README.md`
- Modify: `docs/guides/install-china-apps.md`

**Step 1: Update action lists**

Document the new Guest4K Douyin actions in the current operator docs.

**Step 2: Add example usage**

Show the minimal flow:

- install
- start
- diagnose

**Step 3: Keep historical helper docs separate**

Do not rewrite the old direct-host `douyin-libtnet-*` notes as if they now belong to Guest4K.

### Task 3: Verify on the real Guest4K runtime

**Files:**
- Test: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Run the full Guest4K test file**

Run:

```bash
python3 -m pytest tests/redroid/test_redroid_guest4k_107.py -v
```

Expected: PASS

**Step 2: Launch Douyin through the new script action**

Run:

```bash
SUDO_PASS=123123 zsh redroid/scripts/redroid_guest4k_107.sh douyin-start
```

Expected: `Status: ok`, `Activity: com.ss.android.ugc.aweme/.main.MainActivity`

**Step 3: Collect the diagnosis surface**

Run:

```bash
SUDO_PASS=123123 zsh redroid/scripts/redroid_guest4k_107.sh douyin-diagnose
```

Expected: compact output for package path, pid, top activity, audio state, filtered logcat, and host PipeWire sink inputs
