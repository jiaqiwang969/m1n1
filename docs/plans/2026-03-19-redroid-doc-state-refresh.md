# Redroid Doc State Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refresh the workspace docs so they match the latest verified Douyin live state without changing scripts or repository layout.

**Architecture:** Use the saved live evidence in `tmp/live/20260319-134419-douyin-surfacecontrol-surfaceview-1-current-base/` as the single source of truth for the current blocker. Update only `README.md` and `docs/guides/install-china-apps.md`, while preserving the `libtnet` workflow as forensic tooling instead of headline status.

**Tech Stack:** Markdown, `rg`, `sed`, saved live logs

---

### Task 1: Capture the current evidence anchors

**Files:**
- Validate: `tmp/live/20260319-134419-douyin-surfacecontrol-surfaceview-1-current-base/baseline.txt`
- Validate: `tmp/live/20260319-134419-douyin-surfacecontrol-surfaceview-1-current-base/patched-run.txt`
- Validate: `tmp/live/20260319-134419-douyin-surfacecontrol-surfaceview-1-current-base/changes.json`

**Step 1: Inspect the baseline evidence**

Run: `rg -a -n "pageSizeCompat|MainActivity|Cronet_CertVerify_DoVerify|VOutle2|libttmplayer" tmp/live/20260319-134419-douyin-surfacecontrol-surfaceview-1-current-base/baseline.txt`

Expected: matches for `pageSizeCompat=36`, `MainActivity`, `Cronet_CertVerify_DoVerify`, and `VOutle2-V1` frames in `libttmplayer.so`.

**Step 2: Inspect the single-variable experiment**

Run: `rg -n "hash before patch|MainActivity|VOutle2|libttmplayer|restored original hash" tmp/live/20260319-134419-douyin-surfacecontrol-surfaceview-1-current-base/patched-run.txt`

Expected: the patch changes the hash from `4d06...` to `7ff4...`, still reaches `MainActivity`, still crashes in `VOutle2-V1` / `libttmplayer.so`, then restores the original hash.

### Task 2: Refresh the workspace README

**Files:**
- Modify: `README.md`

**Step 1: Replace stale current-state claims**

Update the top status bullets and the Douyin lessons section so they say the newest live blocker is `VOutle2-V1` / `libttmplayer.so`, not patched `libtnet` / `JNI_OnLoad`.

**Step 2: Reframe `libtnet` tooling**

Keep the `douyin-libtnet-*` workflow documentation, but describe it as reproducibility / audit tooling and earlier-stage history.

**Step 3: Refresh the next-phase list**

Document the next debug direction as the `libttmplayer` media/render path plus the disproven `player_enable_surfacecontrol_surfaceview=1` experiment.

### Task 3: Refresh the China-app guide

**Files:**
- Modify: `docs/guides/install-china-apps.md`

**Step 1: Update the current conclusion**

Replace the old "current first blocker is patched `libtnet`" summary with the new baseline conclusion: launch reaches `MainActivity`, then crashes in `VOutle2-V1` / `libttmplayer.so`.

**Step 2: Update the recommendation section**

Keep the `douyin-libtnet-*` commands, but change the narrative so the current practical next direction is `libttmplayer`, not `libtnet`.

**Step 3: Replace the stale live-validation section**

Document the fresh baseline evidence, the `Cronet_CertVerify_DoVerify` fallback behavior, the `VOutle2-V1` crash, and the failed `player_enable_surfacecontrol_surfaceview=1` experiment.

### Task 4: Verify the doc refresh

**Files:**
- Validate: `README.md`
- Validate: `docs/guides/install-china-apps.md`

**Step 1: Search for stale blocker claims**

Run: `rg -n "current latest live native blocker is patched `libtnet`|libtnet remains the current next gate|当前最新可稳定复现的 cold-start 主阻塞仍然是 patched `libtnet`|优先处理 patched `libtnet`" README.md docs/guides/install-china-apps.md`

Expected: no matches.

**Step 2: Search for new evidence anchors**

Run: `rg -n "4d06f00d|7ff4ab55|VOutle2-V1|libttmplayer.so|surfacecontrol_surfaceview" README.md docs/guides/install-china-apps.md`

Expected: matches in both docs.

**Step 3: Spot-check the edited files**

Run: `sed -n '1,120p' README.md && sed -n '1,120p' docs/guides/install-china-apps.md`

Expected: the current-summary sections now agree with the saved live evidence.
