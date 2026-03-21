# Minigbm Lock Trace Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add gated lock-path tracing to minigbm, rebuild and deploy the affected graphics artifacts, and capture one evidence-backed Douyin repro.

**Architecture:** Keep the change minimal and forensic. Add a shared `REDROID_LOCK_TRACE` marker to the mapper, gralloc core, and protection decision point; gate all new logging on a debug property; then verify the built binaries and live runtime with one controlled repro.

**Tech Stack:** C++, C, Android logcat, AOSP minigbm, `ssh`, `scp`, `adb`, `podman`, Markdown

## Status Update

Latest validated state:

- local source patches are in `/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/...`
- rebuilt live graphics hashes are:
  - `libminigbm_gralloc.so`: `8d896425e62e73ecbccbf7b5528aa9123997df59a1515a7ed054791f3ab2a9a7`
  - `libminigbm_gralloc4_utils.so`: `a5cb7233bee3537322adcde10dce10825749235bd7abf4ab182725218c11f00f`
  - `mapper.minigbm.so`: `6225429d9fd36b040d4e1a47b2444cd53609b09f8719edca05a0eca7a36501fe`
  - `android.hardware.graphics.allocator-service.minigbm`: `22c0569746fdc93cc730570ede230f32e615bceb6a687c477cbecd01599465a6`
- live repro evidence is under `tmp/live/20260319-minigbm-locktrace-deploy/repro/`
- the traced Douyin cold-start now shows `REDROID_LOCK_TRACE` on the live host
- observed Douyin buffer locks use `map_flags=0x2` and `drv_get_prot()` returns `PROT_READ|PROT_WRITE`
- surfaceflinger locks show `map_flags=0x3` and also resolve to `PROT_READ|PROT_WRITE`
- the controlled repro still crashes, but the crash is now on thread `#UPush-1` in patched `libtnet-3.1.14.so` `JNI_OnLoad`
- latest evidence file: `tmp/live/20260319-minigbm-locktrace-deploy/repro/tombstone_26.txt`
- current conclusion: the traced minigbm path does not support the hypothesis that Douyin's observed cold-start crash is caused by missing write permission on the gralloc lock path

---

### Task 1: Prove the current binaries do not yet contain the trace marker

**Files:**
- Validate: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/lib64/libminigbm_gralloc.so`

**Step 1: Run the red test**

Run:

```bash
ssh dell@192.168.1.104 \
  "strings /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/lib64/libminigbm_gralloc.so | grep REDROID_LOCK_TRACE"
```

Expected: exit non-zero because the marker string is absent.

### Task 2: Add gated tracing to the minigbm lock path

**Files:**
- Modify: `/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/drv_helpers.c`
- Modify: `/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/cros_gralloc/cros_gralloc_buffer.cc`
- Modify: `/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/cros_gralloc/cros_gralloc_driver.cc`
- Modify: `/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/cros_gralloc/gralloc4/CrosGralloc4Utils.cc`
- Modify: `/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/cros_gralloc/gralloc4/CrosGralloc4Mapper.cc`

**Step 1: Add a property-gated helper and `REDROID_LOCK_TRACE` logs**

Capture:

- `cpuUsage`
- `mapUsage`
- handle `usage`
- handle `format`
- buffer size
- `map_flags`
- `BO_MAP_WRITE` presence
- final `PROT_*`

**Step 2: Sync the patched source files to the build host**

Run:

```bash
scp <patched-files> dell@192.168.1.104:/home/dell/redroid-build/redroid16-src-cs/external/minigbm/...
```

Expected: remote source now matches the local patched files.

### Task 3: Rebuild the affected graphics artifacts

**Files:**
- Build: `/home/dell/redroid-build/redroid16-src-cs`

**Step 1: Rebuild only the touched minigbm outputs**

Run:

```bash
ssh dell@192.168.1.104 'bash --login -c "
  cd /home/dell/redroid-build/redroid16-src-cs &&
  source build/envsetup.sh &&
  lunch redroid_arm64_only-bp2a-userdebug &&
  m libminigbm_gralloc libminigbm_gralloc4_utils mapper.minigbm android.hardware.graphics.allocator-service.minigbm
"'
```

Expected: build succeeds.

**Step 2: Run the green test**

Run:

```bash
ssh dell@192.168.1.104 \
  "strings /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/lib64/libminigbm_gralloc.so | grep REDROID_LOCK_TRACE"
```

Expected: `REDROID_LOCK_TRACE` appears in the rebuilt binary.

### Task 4: Deploy the rebuilt artifacts to the live container baseline

**Files:**
- Deploy to host rootfs: `/home/wjq/redroid-artifacts/rootfs/vendor/...`
- Validate live container: `redroid16k-root-safe`

**Step 1: Copy rebuilt graphics artifacts to the Asahi host rootfs**

Copy:

- `libminigbm_gralloc.so`
- `libminigbm_gralloc4_utils.so`
- `mapper.minigbm.so`
- `android.hardware.graphics.allocator-service.minigbm`

**Step 2: Restart the current Redroid container and repair file modes**

Run the existing restart path and verify:

- `sys.boot_completed=1`
- `init.svc.vendor.vncserver=running`
- `/system/etc/llndk.libraries.txt` and `sanitizer.libraries.txt` are `0644`

### Task 5: Capture one traced Douyin repro

**Files:**
- Create evidence under: `/Users/jqwang/25-红手指手机/m1n1/tmp/live/`

**Step 1: Enable the trace property**

Run:

```bash
adb -s 127.0.0.1:5555 shell setprop debug.redroid.minigbm_locktrace 1
```

**Step 2: Clear logcat and reproduce Douyin once**

Run:

```bash
adb -s 127.0.0.1:5555 shell logcat -c
adb -s 127.0.0.1:5555 shell am force-stop com.ss.android.ugc.aweme
adb -s 127.0.0.1:5555 shell am start -W -n com.ss.android.ugc.aweme/.splash.SplashActivity
```

**Step 3: Pull the trace and crash evidence**

Collect:

- `logcat` lines containing `REDROID_LOCK_TRACE`
- the latest crash excerpt
- the newest tombstone if the app still crashes

### Task 6: Summarize the result and update docs

**Files:**
- Modify: `/Users/jqwang/25-红手指手机/m1n1/README.md`
- Modify: `/Users/jqwang/25-红手指手机/m1n1/docs/guides/install-china-apps.md`

**Step 1: Record what the trace proved**

Capture whether write intent is absent at mapper entry or lost later.

Validated result:

- on the observed Douyin cold-start path, write intent is present by the time minigbm maps the buffer
- `drv_get_prot()` returns `PROT_READ|PROT_WRITE`, not `PROT_READ`
- the repro therefore pivots away from minigbm lock permissions and back to the patched `libtnet` / 16 KB native-library mapping problem

**Step 2: Note runtime restoration state**

Record the final deployed hashes and whether the container remains on the known-good baseline after the experiment.
