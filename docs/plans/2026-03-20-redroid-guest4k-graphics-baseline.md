# Redroid Guest4K Graphics Baseline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a narrow, test-backed graphics-profile surface to the Guest4K operator so Guest4K graphics experiments become reproducible without changing the current bootable default path.

**Architecture:** Treat Guest4K graphics repair as a separate layer from Douyin itself. Keep the current `guest-all-dri` restart path as the default baseline, then add one explicit experimental `guest-vkms` profile that changes only DRI exposure behavior. Use dry-run tests first so the operator contract is visible and stable before the next live experiment.

**Tech Stack:** `zsh`, `ssh`, `podman`, `adb`, `python3`, `unittest`, Markdown

---

### Task 1: Capture the fresh evidence anchors

**Files:**
- Validate: `redroid/scripts/redroid_guest4k_107.sh`
- Validate: `docs/plans/2026-03-20-redroid-guest4k-graphics-baseline-design.md`

**Step 1: Re-verify the current Guest4K baseline**

Run: `SUDO_PASS=123123 zsh redroid/scripts/redroid_guest4k_107.sh verify`

Expected:

- guest SSH succeeds
- guest page size is `4096`
- `adb connect 127.0.0.1:5556` shows `device`
- `sys.boot_completed=1`
- `init.svc.vendor.vncserver=running`
- VNC returns an `RFB` banner

**Step 2: Re-verify the current graphics failure signature**

Run:

```bash
ssh wjq@192.168.1.107 \
  "adb -s 127.0.0.1:5556 shell logcat -c >/dev/null 2>&1 || true; \
   adb -s 127.0.0.1:5556 shell am force-stop com.ss.android.ugc.aweme >/dev/null 2>&1 || true; \
   adb -s 127.0.0.1:5556 shell am start -W -n com.ss.android.ugc.aweme/.main.MainActivity; \
   sleep 10; \
   adb -s 127.0.0.1:5556 shell logcat -d 2>/dev/null | \
   grep -iE 'DRM_IOCTL_MODE_CREATE_DUMB failed|Failed to create bo|drawRenderNode called on a context with no surface'"
```

Expected:

- `am start -W` completes
- logcat contains `CREATE_DUMB failed`
- logcat contains `Failed to create bo`
- logcat contains `drawRenderNode called on a context with no surface`

### Task 2: Add the failing operator tests first

**Files:**
- Modify: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Add a default-profile test**

Add a dry-run test that asserts:

- `--dry-run restart` exits `0`
- output mentions the default graphics profile name
- output still contains `-v /dev/dri:/dev/dri`

**Step 2: Add an experimental-profile test**

Run the script with:

```bash
GRAPHICS_PROFILE=guest-vkms VKMS_CARD_NODE=/dev/dri/card1 \
zsh redroid/scripts/redroid_guest4k_107.sh --dry-run restart
```

Add assertions that dry-run output contains:

- the experimental profile name
- `modprobe vkms`
- `-v /dev/dri/card1:/dev/dri/renderD128`
- explicit masked DRI paths
- no `-v /dev/dri:/dev/dri`

**Step 3: Run the tests to verify red**

Run: `python3 -m unittest tests/redroid/test_redroid_guest4k_107.py -v`

Expected: FAIL because the script does not yet support the new graphics-profile behavior.

### Task 3: Implement the minimal graphics-profile surface

**Files:**
- Modify: `redroid/scripts/redroid_guest4k_107.sh`

**Step 1: Add the new environment surface**

Add:

- `GRAPHICS_PROFILE`
- `VKMS_CARD_NODE`

Use defaults that preserve the current script behavior.

**Step 2: Split graphics-mount generation into helpers**

Add small helpers that build the DRI-related `podman run` fragment for:

- `guest-all-dri`
- `guest-vkms`

Keep the implementation narrow. Do not refactor unrelated SSH, ADB, or viewer logic.

**Step 3: Make restart log the chosen profile**

The `restart` path should print the active graphics profile before launching Redroid. Dry-run output must make the selected shape obvious.

**Step 4: Keep the default path unchanged**

The default profile must still resolve to the current known-booting shape:

- `--privileged`
- `-v /dev/dri:/dev/dri`
- published ADB and VNC ports
- no `--network host`

### Task 4: Verify green locally

**Files:**
- Validate: `tests/redroid/test_redroid_guest4k_107.py`
- Validate: `redroid/scripts/redroid_guest4k_107.sh`

**Step 1: Run the unit tests**

Run: `python3 -m unittest tests/redroid/test_redroid_guest4k_107.py -v`

Expected: PASS.

**Step 2: Spot-check the dry-run contract**

Run:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh --dry-run restart
GRAPHICS_PROFILE=guest-vkms VKMS_CARD_NODE=/dev/dri/card1 \
  zsh redroid/scripts/redroid_guest4k_107.sh --dry-run restart
```

Expected:

- the default output still shows `/dev/dri:/dev/dri`
- the experimental output shows `modprobe vkms`
- the experimental output shows remapped and masked DRI mounts
- neither output contains `--network host`

### Task 5: Live-verify only the safe baseline in this pass

**Files:**
- Modify: none

**Step 1: Restart the default profile**

Run:

```bash
export SUDO_PASS=123123
zsh redroid/scripts/redroid_guest4k_107.sh restart
zsh redroid/scripts/redroid_guest4k_107.sh verify
```

Expected:

- Guest4K still boots
- ADB is `device`
- VNC still returns `RFB`

**Step 2: Record the next live experiment boundary**

Do not switch the working default to `guest-vkms` in this same pass.

Instead, document that the next live step is:

```bash
export SUDO_PASS=123123
GRAPHICS_PROFILE=guest-vkms VKMS_CARD_NODE=/dev/dri/card1 \
  zsh redroid/scripts/redroid_guest4k_107.sh restart
```

Expected:

- no success claim yet
- only a reproducible experimental entry point for the next round of evidence gathering
