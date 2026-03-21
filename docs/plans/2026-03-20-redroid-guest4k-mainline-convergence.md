# Redroid Guest4K Mainline Convergence Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Promote the fixed Guest4K runtime to the repository's default Redroid baseline and downgrade the old direct-host 16K path to legacy/supporting status.

**Architecture:** Keep the upstream `m1n1` tree intact and treat the local Redroid layer as a separate operator surface. Use a dedicated Guest4K image tag, preserve the current working container/runtime shape, and update the durable docs so future work starts from the booting `16K Asahi host -> 4K guest -> Redroid` chain instead of the older direct-host experiments.

**Tech Stack:** `zsh`, `podman`, `ssh`, `adb`, `python3`, `unittest`, Markdown

---

### Task 1: Lock the Guest4K operator contract

**Files:**
- Modify: `tests/redroid/test_redroid_guest4k_107.py`
- Modify: `redroid/scripts/redroid_guest4k_107.sh`

**Step 1: Add a failing test for the default Guest4K image**

Assert that `zsh redroid/scripts/redroid_guest4k_107.sh --dry-run restart` includes:

- `localhost/redroid4k-root:minigbm-dropmaster`
- not `localhost/redroid16k-root:latest`

**Step 2: Run the single test to verify red**

Run: `python3 -m unittest tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_restart_dry_run_shows_isolated_guest_redroid_shape -v`

Expected: FAIL because the script still points at the older image tag.

**Step 3: Switch the script default to the dedicated Guest4K image**

Keep the rest of the operator behavior unchanged.

**Step 4: Re-run the single test to verify green**

Run the same command again.

Expected: PASS.

### Task 2: Capture the fixed Guest4K runtime as durable project state

**Files:**
- Modify: `README.md`
- Modify: `docs/guides/install-china-apps.md`
- Modify: `docs/plans/2026-03-20-redroid-guest4k-root-cause.md`

**Step 1: Rewrite the root README status**

Document:

- Guest4K is now the only recommended runtime baseline
- the working image tag is `localhost/redroid4k-root:minigbm-dropmaster`
- the active graphics shape is full `/dev/dri` exposure inside the 4K guest
- the critical HWC root fix was enabling `DRM_CLIENT_CAP_UNIVERSAL_PLANES` before probing candidate DRM nodes
- direct-host 16K remains only for legacy automation and historical comparison

**Step 2: Rewrite the China-app guide recommendations**

Make Guest4K the operational default and describe direct-host 16K as a legacy path used only where old helper actions have not yet been ported.

**Step 3: Rewrite the Guest4K root-cause note**

Replace the earlier "probably architecture boundary" conclusion with the confirmed source-level fix and the evidence that SurfaceFlinger now boots.

### Task 3: Align the live guest runtime with the new script default

**Files:**
- Modify: none

**Step 1: Ensure the guest podman image tag exists**

On the 4K guest, keep `localhost/redroid4k-root:minigbm-dropmaster` as the currently working fixed image tag used by the operator default.

**Step 2: Verify the image tag resolves to the same image ID as the working container image**

Expected: `localhost/redroid4k-root:minigbm-dropmaster` and the active image reference resolve to the same image ID.

### Task 4: Run local verification

**Files:**
- Validate: `tests/redroid/test_redroid_guest4k_107.py`
- Validate: `redroid/scripts/redroid_guest4k_107.sh`
- Validate: `README.md`
- Validate: `docs/guides/install-china-apps.md`

**Step 1: Run the full Guest4K test file**

Run: `python3 -m unittest tests/redroid/test_redroid_guest4k_107.py -v`

Expected: PASS.

**Step 2: Spot-check the dry-run**

Run: `zsh redroid/scripts/redroid_guest4k_107.sh --dry-run restart`

Expected:

- output includes `localhost/redroid4k-root:minigbm-dropmaster`
- output still shows `-v /dev/dri:/dev/dri`
- output still omits `--network host`

**Step 3: Keep the live success anchor**

Record the latest confirmed runtime state:

- `init.svc.vendor.hwcomposer-3=running`
- `init.svc.surfaceflinger=running`
- `sys.boot_completed=1`
