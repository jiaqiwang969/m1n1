# Guest4K Virgl Logcat Readiness Fanout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reuse the rollout logcat-readiness retry for the remaining Guest4K virgl startup flows that still issue a noisy one-shot `logcat -c`.

**Architecture:** The shell script already has a bounded helper that emits a quiet retry loop for `podman exec <container> /system/bin/logcat -c`. This plan wires that helper into the probe, longrun, and fingerprint flows and adds dry-run regression coverage so the exact shell emitted by `--dry-run` stays stable.

**Tech Stack:** `zsh`, `podman`, `python3 -m unittest`

---

### Task 1: Add failing dry-run regression tests

**Files:**
- Modify: `tests/redroid/test_redroid_guest4k_107.py`
- Test: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Write the failing test**

Add three tests covering:
- `virgl-srcbuild-probe`
- `virgl-srcbuild-longrun`
- `virgl-fingerprint-compare`

Each test should assert that dry-run output contains:
- `logcat_cleared=0`
- the container-specific `if podman exec ... /system/bin/logcat -c >/dev/null 2>&1; then`
- `if [ "${logcat_cleared}" != "1" ]; then`

Each test should also assert that the old bare `podman exec ... /system/bin/logcat -c || true` is absent for that container.

**Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_virgl_srcbuild_probe_dry_run_waits_for_logcat_clear_readiness_after_start tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_virgl_srcbuild_longrun_dry_run_waits_for_logcat_clear_readiness_after_start tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_virgl_fingerprint_compare_dry_run_waits_for_logcat_clear_readiness_after_start`

Expected: FAIL because those paths still emit the old one-shot `logcat -c`.

### Task 2: Reuse the helper in the remaining startup paths

**Files:**
- Modify: `redroid/scripts/redroid_guest4k_107.sh`
- Test: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Write minimal implementation**

Inside each affected function:
- materialize `logcat_clear_cmd="$(guest_container_logcat_clear_cmd "<container>")"`
- replace the bare `podman exec <container> /system/bin/logcat -c || true` with `${logcat_clear_cmd}`

Do not change sleeps, clone behavior, restore behavior, or health/log collection.

**Step 2: Run tests to verify they pass**

Run: `python3 -m unittest tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_virgl_srcbuild_probe_dry_run_waits_for_logcat_clear_readiness_after_start tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_virgl_srcbuild_longrun_dry_run_waits_for_logcat_clear_readiness_after_start tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_virgl_fingerprint_compare_dry_run_waits_for_logcat_clear_readiness_after_start`

Expected: PASS

### Task 3: Run broader verification

**Files:**
- Modify: `redroid/scripts/redroid_guest4k_107.sh`
- Modify: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Run full relevant suite**

Run: `python3 -m unittest tests.redroid.test_redroid_guest4k_107`

Expected: PASS

**Step 2: Run shortened live verification**

Run:
- `SUDO_PASS='codex-nopass' VIRGL_SRCBUILD_PROBE_SECONDS=5 zsh redroid/scripts/redroid_guest4k_107.sh virgl-srcbuild-probe`
- `SUDO_PASS='codex-nopass' VIRGL_SRCBUILD_LONGRUN_CHECKPOINTS='5 10 15' zsh redroid/scripts/redroid_guest4k_107.sh virgl-srcbuild-longrun`
- `SUDO_PASS='codex-nopass' VIRGL_FINGERPRINT_SECONDS=5 zsh redroid/scripts/redroid_guest4k_107.sh virgl-fingerprint-compare`

Expected:
- each action restores the control container
- no `exec: No such file or directory` appears during startup

### Task 4: Commit

**Files:**
- Add: `docs/plans/2026-03-22-guest4k-virgl-logcat-readiness-fanout-design.md`
- Add: `docs/plans/2026-03-22-guest4k-virgl-logcat-readiness-fanout.md`
- Modify: `redroid/scripts/redroid_guest4k_107.sh`
- Modify: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Review staged files**

Run: `git diff --cached --stat`

**Step 2: Commit**

```bash
git add docs/plans/2026-03-22-guest4k-virgl-logcat-readiness-fanout-design.md \
        docs/plans/2026-03-22-guest4k-virgl-logcat-readiness-fanout.md \
        redroid/scripts/redroid_guest4k_107.sh \
        tests/redroid/test_redroid_guest4k_107.py
git commit -m "Extend virgl logcat readiness retries"
```
