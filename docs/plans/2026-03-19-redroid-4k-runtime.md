# Redroid 4K Runtime Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an explicit 4 KB Redroid runtime path alongside the current 16 KB baseline so Douyin can be tested on a 4 KB guest without destabilizing the existing workflow.

**Architecture:** Keep the current 16 KB actions as-is and introduce a second runtime profile selected by new sibling actions. Reuse the same restart, verify, and viewer mechanics with alternate image, container, volume, and port values. Teach the viewer helper to accept an ADB serial override instead of cloning the tool.

**Tech Stack:** `zsh`, Python 3, `unittest`, `adb`, `podman`, `ssh`

---

### Task 1: Add failing tests for the 4 KB command surface

**Files:**
- Modify: `tests/redroid/test_redroid_root_safe_107.py`
- Create: `tests/redroid/test_redroid_viewer.py`

**Step 1: Write the failing dry-run tests**

Add tests that assert:

- `--dry-run restart-4k` exits `0`
- dry-run output mentions `docker.io/redroid/redroid:16.0.0_64only-latest`
- dry-run output mentions `--name redroid4k-root-safe`
- dry-run output mentions `127.0.0.1:5556:5555`
- dry-run output mentions `127.0.0.1:5901:5900`
- dry-run output mentions `redroid4k-data-root`
- `--dry-run verify-4k` exits `0`

Add a viewer test that asserts the helper reads an environment override for the ADB serial.

**Step 2: Run tests to verify failure**

Run:

```bash
python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v
python3 -m unittest tests/redroid/test_redroid_viewer.py -v
```

Expected: FAIL because the 4 KB actions and viewer override do not exist yet.

### Task 2: Implement the minimal 4 KB runtime profile

**Files:**
- Modify: `redroid/scripts/redroid_root_safe_107.sh`

**Step 1: Add 4 KB runtime constants**

Add explicit values for:

- 4 KB image
- 4 KB container name
- 4 KB ADB/VNC bindings
- 4 KB data volume

**Step 2: Add profile-selection helpers**

Refactor the script minimally so restart/status/verify/viewer can run against either:

- the current 16 KB profile
- the new 4 KB profile

**Step 3: Add sibling actions**

Add:

- `restart-4k`
- `status-4k`
- `verify-4k`
- `viewer-4k`

### Task 3: Teach the viewer helper to use an alternate ADB serial

**Files:**
- Modify: `redroid/tools/redroid_viewer.py`
- Test: `tests/redroid/test_redroid_viewer.py`

**Step 1: Add the smallest override surface**

Read the ADB serial from an environment variable, defaulting to `127.0.0.1:5555`.

**Step 2: Re-run the viewer test**

Run:

```bash
python3 -m unittest tests/redroid/test_redroid_viewer.py -v
```

Expected: PASS.

### Task 4: Update docs

**Files:**
- Modify: `README.md`
- Modify: `docs/guides/install-china-apps.md`

**Step 1: Document the 4 KB path**

Add:

- the new 4 KB actions
- the 4 KB image/container/port split
- the rationale for using the 4 KB route for Douyin validation

**Step 2: Keep the recommendation explicit**

Document that:

- 16 KB remains the stable baseline
- 4 KB is the current pragmatic route for Douyin runtime experiments

### Task 5: Run local verification

**Files:**
- Validate: `redroid/scripts/redroid_root_safe_107.sh`
- Validate: `redroid/tools/redroid_viewer.py`
- Validate: `tests/redroid/test_redroid_root_safe_107.py`
- Validate: `tests/redroid/test_redroid_viewer.py`

**Step 1: Run the tests**

Run:

```bash
python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v
python3 -m unittest tests/redroid/test_redroid_viewer.py -v
```

**Step 2: Run dry-runs**

Run:

```bash
zsh redroid/scripts/redroid_root_safe_107.sh --dry-run restart-4k
zsh redroid/scripts/redroid_root_safe_107.sh --dry-run verify-4k
zsh redroid/scripts/redroid_root_safe_107.sh --dry-run viewer-4k
```

Expected:

- tests pass
- dry-run output shows the 4 KB runtime values and viewer serial

### Task 6: Live verification on the remote host

**Files:**
- Modify: none

**Step 1: Launch the 4 KB guest**

Run:

```bash
SUDO_PASS=123123 zsh redroid/scripts/redroid_root_safe_107.sh restart-4k
```

**Step 2: Verify the live 4 KB runtime**

Run:

```bash
zsh redroid/scripts/redroid_root_safe_107.sh verify-4k
ssh wjq@192.168.1.107 "adb connect 127.0.0.1:5556 >/dev/null 2>&1; adb -s 127.0.0.1:5556 shell getconf PAGE_SIZE 2>/dev/null || adb -s 127.0.0.1:5556 shell getprop ro.product.cpu.abilist"
```

Expected:

- the guest boots
- ADB responds on `127.0.0.1:5556`
- the runtime is independently reachable from the 16 KB path

### Task 7: Commit

**Step 1: Commit the work**

```bash
git add docs/plans/2026-03-19-redroid-4k-runtime-design.md docs/plans/2026-03-19-redroid-4k-runtime.md README.md docs/guides/install-china-apps.md redroid/scripts/redroid_root_safe_107.sh redroid/tools/redroid_viewer.py tests/redroid/test_redroid_root_safe_107.py tests/redroid/test_redroid_viewer.py
git commit -m "feat: add 4k redroid runtime path"
```
