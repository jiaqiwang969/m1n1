# Guest4K card0 Permission Repair Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the Guest4K mainline runtime consistently select `/dev/dri/card0` by fixing the guest-side DRM device permissions that are bind-mounted into the Redroid container.

**Architecture:** Keep the repair narrow and operational. First add a dry-run regression test that proves the Guest4K operator script prepares a persistent `udev` rule plus an immediate `chmod` for `/dev/dri/card0`. Then implement the minimal script change, verify the test passes, and update the root-cause docs and README so the project state no longer reflects the older incomplete diagnosis.

**Tech Stack:** zsh operator script, pytest/unittest dry-run tests, Guest4K `udev`, podman, adb, project Markdown docs

---

### Task 1: Add a failing operator-script regression test

**Files:**
- Modify: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Write the failing test**

Add a dry-run assertion for the `restart` action that expects:

- a `99-redroid-dri.rules` `udev` rule for `card0`
- `MODE="0666"` in that rule
- an immediate `chmod 666 /dev/dri/card0`

**Step 2: Run test to verify it fails**

Run: `pytest tests/redroid/test_redroid_guest4k_107.py -q`

Expected: FAIL because the current `guest-all-dri` path does not emit the permission-repair commands.

### Task 2: Implement the minimal Guest4K permission repair

**Files:**
- Modify: `redroid/scripts/redroid_guest4k_107.sh`

**Step 1: Add the minimal implementation**

For `guest-all-dri`, emit commands that:

- write `/etc/udev/rules.d/99-redroid-dri.rules`
- reload `udev`
- trigger `/dev/dri/card0`
- run `chmod 666 /dev/dri/card0 || true`

Keep the existing `guest-vkms` behavior unchanged.

**Step 2: Run test to verify it passes**

Run: `pytest tests/redroid/test_redroid_guest4k_107.py -q`

Expected: PASS.

### Task 3: Update project state docs

**Files:**
- Modify: `README.md`
- Modify: `docs/plans/2026-03-20-redroid-guest4k-root-cause.md`
- Modify: `docs/plans/2026-03-20-minigbm-node-selection-repair.md`

**Step 1: Record the corrected root cause**

Update docs to reflect:

- the HWC probe fix was necessary but not sufficient
- the later deeper blocker was guest `/dev/dri/card0` permissions
- the Redroid container inherits guest DRM node permissions via bind mount
- the durable operational repair is the guest-side `udev` rule for `card0`

**Step 2: Record the verification evidence**

Include:

- `boot_completed=1`
- `allocator-service.minigbm` selecting `/dev/dri/card0`
- `surfaceflinger` selecting `/dev/dri/card0`
- `am start -W -n com.android.settings/.homepage.SettingsHomepageActivity` returning `Status: ok`
- no fresh `DRM_IOCTL_MODE_CREATE_DUMB failed` / `Failed to create bo` / `drawRenderNode...no surface`
