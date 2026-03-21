# Minigbm Lock Upgrade Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent cached read-only minigbm mappings from being reused by later read-write locks.

**Architecture:** Keep the existing cached mapping path in `cros_gralloc_buffer`, but detect when a
later lock asks for stronger permissions and upgrade the cached VMA in place with `mprotect()`.
Cover the decision logic with a small host unit test, then rebuild and validate the Douyin startup
path on the current baseline.

**Tech Stack:** AOSP `external/minigbm`, Soong `cc_test_host`, gtest, redroid deployment on Asahi
host

---

### Task 1: Add a Failing Regression Test for Permission Upgrade Decisions

**Files:**
- Create: `/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/cros_gralloc/cros_gralloc_lock_utils.h`
- Create: `/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/cros_gralloc/cros_gralloc_lock_utils_unittest.cc`
- Modify: `/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/Android.bp`

**Step 1: Write the failing test**

Add host unit tests that assert:
- read-only cached mapping + read-write request requires upgrade
- read-write cached mapping + read-only request does not require upgrade
- merged flags keep read and write bits once write has appeared

**Step 2: Run test to verify it fails**

Run:

```bash
source build/envsetup.sh
lunch redroid_arm64_only-bp2a-userdebug
m minigbm_lock_utils_host_test
```

Expected: build fails because the helper header / target does not exist yet, or tests fail because
the helper behavior is not implemented.

### Task 2: Implement the Minimal Permission Upgrade Logic

**Files:**
- Modify: `/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/cros_gralloc/cros_gralloc_buffer.cc`
- Create: `/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/cros_gralloc/cros_gralloc_lock_utils.h`

**Step 1: Add helper functions**

Add small inline helpers to:
- detect whether cached `map_flags` need stronger protection
- compute merged protection flags

**Step 2: Update cached mapping reuse**

In `cros_gralloc_buffer::lock()`:
- inspect `lock_data_[0]->vma->map_flags`
- call `mprotect()` before reuse if the cached mapping lacks requested write permission
- update `vma->map_flags` after successful upgrade
- preserve existing invalidate / reuse flow for compatible locks

**Step 3: Keep logging evidence-focused**

If the upgrade path runs while `REDROID_LOCK_TRACE` is enabled, add one succinct log line showing:
- cached flags
- requested flags
- upgraded flags

### Task 3: Verify the Unit Test Goes Green

**Files:**
- Test: `/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/cros_gralloc/cros_gralloc_lock_utils_unittest.cc`

**Step 1: Run test to verify it passes**

Run:

```bash
source build/envsetup.sh
lunch redroid_arm64_only-bp2a-userdebug
m minigbm_lock_utils_host_test
```

Expected: target builds successfully and the host test passes.

### Task 4: Rebuild the Runtime Library and Deploy

**Files:**
- Build output: `/Users/jqwang/25-红手指手机/redroid16-src/out/.../vendor/lib64/libminigbm_gralloc.so`
- Remote runtime image on `dell@192.168.1.104`
- Target host on `wjq@192.168.1.107`

**Step 1: Build the patched library**

Run:

```bash
source build/envsetup.sh
lunch redroid_arm64_only-bp2a-userdebug
m libminigbm_gralloc
```

Expected: `libminigbm_gralloc` rebuilds without errors.

**Step 2: Deploy to the target image**

Copy the rebuilt library into the redroid image used by the Asahi host and restart the container.

**Step 3: Preserve baseline app config**

Before runtime validation, confirm the Douyin config hash is still:

```text
4d06f00da45dd71a839b58d9187dc2d489a57efaecd9936b864e7c5243f9fd4d
```

### Task 5: Validate the Fix Against the Known Crash

**Files:**
- Create: `/Users/jqwang/25-红手指手机/m1n1/tmp/live/<timestamp>-douyin-minigbm-lock-upgrade/`

**Step 1: Reproduce the prior startup path**

Run the same baseline launch flow with full `REDROID_LOCK_TRACE`.

**Step 2: Compare outcome**

Success criteria:
- Douyin no longer dies immediately on startup
- no `SIGSEGV` / `SEGV_ACCERR` at the prior fault address
- no tombstone with a crashing `r-- /dev/dri/renderD128` mapping reused for write

**Step 3: Capture follow-up evidence if needed**

If Douyin still crashes, save the new `logcat` and tombstone so the next iteration can compare the
new fault address and mapping permissions directly.
