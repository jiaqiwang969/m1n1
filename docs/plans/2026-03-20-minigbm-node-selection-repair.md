# Minigbm Node Selection Repair Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the Guest4K Android UI stack stop crashing by changing minigbm's DRM node selection so the software-rendering path prefers `card*` nodes over `renderD*` nodes.

**Architecture:** Keep the fix narrow. Add a tiny, testable helper that defines the node-probe order, prove with a failing host unit test that software rendering should prefer card nodes first, then wire that helper into `cros_gralloc_driver.cc`. Rebuild only the minigbm artifacts, deploy them into the Guest4K image/container, and re-run the existing `Settings` repro.

**Tech Stack:** AOSP `external/minigbm`, Soong `cc_test_host`, gtest, redroid Guest4K runtime, `ssh`, `adb`, `podman`

---

## Result

This plan was executed through the host-test stage, an initial runtime deployment experiment, and a later root-level completion pass.

- The red test failed for the expected reason:
  `cros_gralloc_node_order.h` did not exist yet.
- The minimal helper was then added and the host gtest passed:
  software rendering => `card-first`
  hardware rendering => `render-first`
- The affected runtime targets rebuilt successfully on
  `/home/dell/redroid-build/redroid16-src-cs`.

The first runtime result was mixed and important:

- A plain `podman cp` into the running Guest4K container did not actually replace the active
  `/vendor/lib64/libminigbm_gralloc.so`.
- After directly replacing `libminigbm_gralloc.so` in the container overlay rootfs and restarting the
  container, the new library hash was confirmed live inside the guest container.
- With that patched library active, the old allocator crash signature stopped being the first failure.
  Fresh boot logs no longer centered on:
  `DRM_IOCTL_MODE_CREATE_DUMB failed`
  `Failed to create bo`
  `drawRenderNode called on a context with no surface`
- The failure moved earlier in the graphics stack to:
  `SurfaceFlinger: Initial display configuration failed: HWC did not hotplug`

Interim conclusion after the node-order-only stage:

- the minigbm node-order repair is real and does change runtime behavior
- but it is not sufficient by itself to produce a stable Guest4K mainline runtime
- the next repair step must target the HWC/display hotplug path that becomes visible once the allocator
  path is no longer the first blocker
- after the experiment, the runtime was restored to the previous stable Guest4K baseline

Later follow-up instrumentation narrowed the remaining blocker further:

- the patched runtime selected `/dev/dri/card0` and still saw a connected `virtio_gpu` connector
- but `DrmClient::init()` then logged `failed to get master drm device`
- the HWC service process was observed holding two open fds for `/dev/dri/card0`

Current best interpretation from that intermediate stage:

- the card-first minigbm path is no longer just a vague suspicion
- HWC instrumentation now shows that `DrmClient::init()` starts with an existing
  `fd=6 -> /dev/dri/card0` that is already `isMaster=1`
- `OpenPreferredDrmFd()` then opens a later `fd=7 -> /dev/dri/card0`, returns that fd, and
  `drmSetMaster(fd=7)` fails with `errno=13`
- the remaining inference is only which earlier code path created `fd=6`
- because this only appears in the card-first minigbm experiment, minigbm remains the strongest
  candidate for that earlier opener
- the visible `HWC did not hotplug` failure is therefore downstream of DRM-master ownership, not a
  standalone display-discovery bug

## Final Completion

That remaining blocker was later fixed in the same source area by adding immediate master release on
card-node init opens.

Confirmed final repair shape in the remote tree on `dell@192.168.1.104`:

- `cros_gralloc_node_order.h` keeps software rendering on `card-first`
- `cros_gralloc_drm_master_utils.h` adds `drop_master_on_init_open_if_needed()`
- `cros_gralloc_driver.cc` now combines both behaviors

Those rebuilt artifacts were packaged into the guest image tag:

- `localhost/redroid4k-root:minigbm-dropmaster`

Verified live hashes on `wjq@192.168.1.107`:

- `9d005935a9f9360e5cfb0f6cfe09b5b054cefa359532383c3f80bd371c44c3aa`
  `android.hardware.graphics.allocator-service.minigbm`
- `87ccca00535c1fa88967b2f06c46bd2fdaceaeb1007e111f4b281d96c01a7c1a`
  `libminigbm_gralloc.so`
- `514af1c111b658dd237f2a0a8e7cd3404867a292dc7712513d801500e99c6b45`
  `mapper.minigbm.so`

Verified runtime proof:

- `sys.boot_completed=1`
- host `127.0.0.1:5901` returns `RFB 003.008`
- `am start -W -n com.android.settings/.homepage.SettingsHomepageActivity` returns `Status: ok`
- `dumpsys activity activities` shows
  `topResumedActivity=...SettingsHomepageActivity`
- fresh log tail no longer contains:
  `DRM_IOCTL_MODE_CREATE_DUMB failed`
  `Failed to create bo`
  `drawRenderNode called on a context with no surface`
  `failed to get master drm device`
  `HWC did not hotplug`

Final conclusion:

- node-order alone was not enough
- node-order plus immediate DRM master drop on card-node init opens is enough for the current Guest4K
  runtime
- this repair line is no longer an experiment; it is the current working Guest4K graphics baseline

### Task 1: Add a failing node-order unit test

**Files:**
- Create: `/home/dell/redroid-build/redroid16-src-cs/external/minigbm/cros_gralloc/cros_gralloc_node_order_unittest.cc`
- Modify: `/home/dell/redroid-build/redroid16-src-cs/external/minigbm/Android.bp`

**Step 1: Write the failing test**

Create a host gtest that asserts:

- software-rendering mode returns `card-first`
- non-software-rendering mode returns `render-first`

Expected test shape:

```cpp
TEST(CrosGrallocNodeOrderTest, SoftwareRenderingPrefersCardNodesFirst) {
    const auto order = cros_gralloc_get_init_node_order(true);
    EXPECT_EQ(order[0], CrosGrallocDrmNodeType::kCard);
    EXPECT_EQ(order[1], CrosGrallocDrmNodeType::kRender);
}

TEST(CrosGrallocNodeOrderTest, HardwareRenderingPrefersRenderNodesFirst) {
    const auto order = cros_gralloc_get_init_node_order(false);
    EXPECT_EQ(order[0], CrosGrallocDrmNodeType::kRender);
    EXPECT_EQ(order[1], CrosGrallocDrmNodeType::kCard);
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
ssh dell@192.168.1.104 'bash --login -c "
  cd /home/dell/redroid-build/redroid16-src-cs &&
  source build/envsetup.sh &&
  lunch redroid_arm64_only_4k-userdebug &&
  m cros_gralloc_node_order_host_test
"'
```

Expected: FAIL because `cros_gralloc_get_init_node_order` / related declarations do not exist yet.

### Task 2: Implement the minimal helper and wire it into minigbm

**Files:**
- Create: `/home/dell/redroid-build/redroid16-src-cs/external/minigbm/cros_gralloc/cros_gralloc_node_order.h`
- Modify: `/home/dell/redroid-build/redroid16-src-cs/external/minigbm/cros_gralloc/cros_gralloc_driver.cc`

**Step 1: Write minimal implementation**

Add a header-only helper with:

- `enum class CrosGrallocDrmNodeType { kRender, kCard };`
- `std::array<CrosGrallocDrmNodeType, 2> cros_gralloc_get_init_node_order(bool is_software_rendering);`

Behavior:

- `true` -> `{kCard, kRender}`
- `false` -> `{kRender, kCard}`

Then update `init_try_nodes()` in `cros_gralloc_driver.cc` to use that order instead of the current hard-coded render-first probe order.

**Step 2: Run the host test to verify it passes**

Run:

```bash
ssh dell@192.168.1.104 'bash --login -c "
  cd /home/dell/redroid-build/redroid16-src-cs &&
  source build/envsetup.sh &&
  lunch redroid_arm64_only_4k-userdebug &&
  m cros_gralloc_node_order_host_test
"'
```

Expected: PASS.

### Task 3: Rebuild the runtime artifacts touched by the fix

**Files:**
- Validate: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only_4k/vendor/bin/hw/android.hardware.graphics.allocator-service.minigbm`
- Validate: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only_4k/vendor/lib64/hw/mapper.minigbm.so`
- Validate: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only_4k/vendor/lib64/libminigbm_gralloc.so`

**Step 1: Build the minimal affected targets**

Run:

```bash
ssh dell@192.168.1.104 'bash --login -c "
  cd /home/dell/redroid-build/redroid16-src-cs &&
  source build/envsetup.sh &&
  lunch redroid_arm64_only_4k-userdebug &&
  m libminigbm_gralloc mapper.minigbm android.hardware.graphics.allocator-service.minigbm
"'
```

Expected: BUILD SUCCESSFUL.

### Task 4: Deploy the rebuilt Guest4K minigbm stack

**Files:**
- Deploy from: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only_4k/...`
- Deploy to image/container: `localhost/redroid4k-root:latest` / `redroid16kguestprobe`

**Step 1: Replace the three rebuilt artifacts in the running Guest4K container**

Artifacts:

- `android.hardware.graphics.allocator-service.minigbm`
- `mapper.minigbm.so`
- `libminigbm_gralloc.so`

**Step 2: Restart Guest4K**

Run:

```bash
ssh wjq@192.168.1.107 '
  SUDO_PASS=123123 zsh /Users/jqwang/25-红手指手机/m1n1/redroid/scripts/redroid_guest4k_107.sh restart
'
```

Expected: container restarts and `127.0.0.1:5556` comes back.

### Task 5: Verify the runtime repro moved

**Files:**
- Validate: `/Users/jqwang/25-红手指手机/m1n1/docs/plans/2026-03-20-redroid-guest4k-root-cause.md`

**Step 1: Re-run the existing Settings repro**

Run:

```bash
ssh wjq@192.168.1.107 '
  adb connect 127.0.0.1:5556 >/dev/null 2>&1 || true
  adb -s 127.0.0.1:5556 shell logcat -c
  adb -s 127.0.0.1:5556 shell am start -W -n com.android.settings/.Settings
  sleep 4
  adb -s 127.0.0.1:5556 shell logcat -d | grep -Ei "DRM_IOCTL_MODE_CREATE_DUMB|Failed to create bo|GraphicBufferAllocator: Failed to allocate|drawRenderNode called on a context with no surface"
'
```

Expected after fix:

- `Settings` remains foreground instead of bouncing to launcher
- no fresh `DRM_IOCTL_MODE_CREATE_DUMB failed`
- no fresh `Failed to create bo`

Expected if still broken:

- same allocator failure signature remains, which means node-order alone was insufficient

### Task 6: Record the result

**Files:**
- Modify: `/Users/jqwang/25-红手指手机/m1n1/docs/plans/2026-03-20-redroid-guest4k-root-cause.md`
- Modify: `/Users/jqwang/25-红手指手机/m1n1/README.md`

**Step 1: Update docs with the result**

If the fix works, record:

- why render-first was wrong for the Guest4K software-rendering path
- which files changed
- which runtime logs disappeared

If it fails, record:

- that node-order was tested and insufficient
- the exact remaining allocator logs
