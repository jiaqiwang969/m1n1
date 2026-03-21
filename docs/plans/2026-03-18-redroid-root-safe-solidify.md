# Redroid Root-Safe Solidify Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Freeze the currently working `redroid16k-root-safe` startup path into a repeatable local helper so future debugging sessions do not regress to the broken image or broken network mode.

**Architecture:** Add one small local launcher/verification script under `tmp/` that targets only the known-good image/container pair on `192.168.1.107`. Guard it with a dry-run-oriented test so the command shape stays pinned to the healthy bridge-network `/init` path.

**Tech Stack:** `zsh`, `ssh`, `sudo`, `podman`, `adb`, `pytest`

---

### Task 1: Lock The Healthy Command Shape

**Files:**
- Create: `tests/python/test_redroid_root_safe_107.py`
- Create: `tmp/redroid_root_safe_107.sh`

**Step 1: Write the failing test**

Add a Python test that runs:

```bash
zsh tmp/redroid_root_safe_107.sh --dry-run restart
```

and asserts the output includes:
- `localhost/redroid16k-root:latest`
- `--network bridge`
- `--name redroid16k-root-safe`
- `-p 127.0.0.1:5555:5555`
- direct `/init` args for `qemu=1 androidboot.hardware=redroid`

**Step 2: Run test to verify it fails**

Run: `pytest tests/python/test_redroid_root_safe_107.py -q`

Expected: FAIL because the helper script does not exist yet.

**Step 3: Write minimal implementation**

Create a `zsh` helper with:
- `restart`
- `status`
- `verify`
- `--dry-run`

Use the healthy container identity:
- image `localhost/redroid16k-root:latest`
- container `redroid16k-root-safe`
- network `bridge`
- port binding `127.0.0.1:5555:5555`

**Step 4: Run test to verify it passes**

Run: `pytest tests/python/test_redroid_root_safe_107.py -q`

Expected: PASS

### Task 2: Verify Against The Live Host

**Files:**
- Validate: `tmp/redroid_root_safe_107.sh`

**Step 1: Dry-run output check**

Run: `zsh tmp/redroid_root_safe_107.sh --dry-run restart`

Expected: printed command uses the healthy bridge `/init` path and never mentions `localhost/redroid16k:latest` or `--network host`.

**Step 2: Live status verification**

Run: `zsh tmp/redroid_root_safe_107.sh status`

Expected:
- container state is `running`
- image is `localhost/redroid16k-root:latest`
- container name is `redroid16k-root-safe`

**Step 3: Live boot verification**

Run: `zsh tmp/redroid_root_safe_107.sh verify`

Expected:
- `sys.boot_completed=1`
- `adb` sees `127.0.0.1:5555`
- `surfaceflinger` and allocator service are `running`
