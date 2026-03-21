# Redroid Host-Mode IMapper Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prove the current host-mode Mesa failure is caused by the Android Soong build not enabling the IMapper backend in `u_gralloc` AUTO selection.

**Architecture:** Make the smallest possible Android-side Mesa change by defining the existing legacy gate macro in `mesa_u_gralloc`, rebuild only that archive, and verify the rebuilt symbol graph changes exactly as expected before touching runtime deployment.

**Tech Stack:** AOSP Soong, Mesa `u_gralloc`, `ssh`, `llvm-nm`, `m`

---

### Task 1: Capture the failing precondition

**Files:**
- Inspect: `/home/dell/redroid-build/redroid16-src-cs/external/mesa3d/src/util/u_gralloc/Android.bp`
- Inspect: `/home/dell/redroid-build/redroid16-src-cs/external/mesa3d/src/util/u_gralloc/u_gralloc.c`

**Step 1: Verify the current Soong file does not define the gate macro**

Run:

```bash
ssh dell@192.168.1.104 \
  "grep -n 'USE_IMAPPER4_METADATA_API' /home/dell/redroid-build/redroid16-src-cs/external/mesa3d/src/util/u_gralloc/Android.bp || true"
```

Expected: no output

**Step 2: Verify the current source gate still depends on the macro**

Run:

```bash
ssh dell@192.168.1.104 \
  "grep -n 'USE_IMAPPER4_METADATA_API' /home/dell/redroid-build/redroid16-src-cs/external/mesa3d/src/util/u_gralloc/u_gralloc.c /home/dell/redroid-build/redroid16-src-cs/external/mesa3d/src/util/u_gralloc/u_gralloc_internal.h"
```

Expected: both files reference `USE_IMAPPER4_METADATA_API`

**Step 3: Verify the current archive contains the implementation but AUTO does not reference it**

Run:

```bash
ssh dell@192.168.1.104 \
  "'/home/dell/redroid-build/redroid16-src-cs/prebuilts/clang/host/linux-x86/clang-r547379/bin/llvm-nm' -A \
   /home/dell/redroid-build/redroid16-src-cs/out/soong/.intermediates/external/mesa3d/src/util/u_gralloc/mesa_u_gralloc/android_vendor_arm64_armv8-a_static/mesa_u_gralloc.a \
   | grep 'u_gralloc_imapper_api_create\|u_gralloc_cros_api_create\|u_gralloc_fallback_create'"
```

Expected:

- `u_gralloc_imapper5_api.o` defines `u_gralloc_imapper_api_create`
- `u_gralloc.o` references `u_gralloc_cros_api_create`
- `u_gralloc.o` references `u_gralloc_fallback_create`
- `u_gralloc.o` does not reference `u_gralloc_imapper_api_create`

### Task 2: Apply the smallest gate fix

**Files:**
- Modify: `/home/dell/redroid-build/redroid16-src-cs/external/mesa3d/src/util/u_gralloc/Android.bp`

**Step 1: Add the gate macro in the Android Soong build**

Change `Android.bp` so `mesa_u_gralloc` defines:

```bp
cflags: ["-DUSE_IMAPPER4_METADATA_API"],
cppflags: ["-DUSE_IMAPPER4_METADATA_API"],
```

Do not rename the macro in this step.

**Step 2: Re-read the modified file**

Run:

```bash
ssh dell@192.168.1.104 \
  "sed -n '1,120p' /home/dell/redroid-build/redroid16-src-cs/external/mesa3d/src/util/u_gralloc/Android.bp"
```

Expected: both `cflags` and `cppflags` contain `-DUSE_IMAPPER4_METADATA_API`

### Task 3: Rebuild and prove the symbol graph changed

**Files:**
- Build output: `/home/dell/redroid-build/redroid16-src-cs/out/soong/.intermediates/external/mesa3d/src/util/u_gralloc/mesa_u_gralloc/android_vendor_arm64_armv8-a_static/mesa_u_gralloc.a`

**Step 1: Rebuild only `mesa_u_gralloc`**

Run:

```bash
ssh dell@192.168.1.104 \
  'bash --login -c "cd /home/dell/redroid-build/redroid16-src-cs && source build/envsetup.sh >/dev/null 2>&1 && lunch redroid_arm64_only-bp2a-userdebug >/dev/null && m mesa_u_gralloc -j8"'
```

Expected: build succeeds

**Step 2: Re-run the symbol inspection**

Run:

```bash
ssh dell@192.168.1.104 \
  "'/home/dell/redroid-build/redroid16-src-cs/prebuilts/clang/host/linux-x86/clang-r547379/bin/llvm-nm' -A \
   /home/dell/redroid-build/redroid16-src-cs/out/soong/.intermediates/external/mesa3d/src/util/u_gralloc/mesa_u_gralloc/android_vendor_arm64_armv8-a_static/mesa_u_gralloc.a \
   | grep 'u_gralloc_imapper_api_create\|u_gralloc_cros_api_create\|u_gralloc_fallback_create'"
```

Expected:

- `u_gralloc.o` now references `u_gralloc_imapper_api_create`

**Step 3: Record the new archive timestamp**

Run:

```bash
ssh dell@192.168.1.104 \
  "ls -l /home/dell/redroid-build/redroid16-src-cs/out/soong/.intermediates/external/mesa3d/src/util/u_gralloc/mesa_u_gralloc/android_vendor_arm64_armv8-a_static/mesa_u_gralloc.a"
```

Expected: fresh timestamp from this rebuild

### Task 4: Stop and reassess before deployment

**Files:**
- Inspect only

**Step 1: Do not deploy yet**

At this point, stop after the archive proof and decide whether the next smallest experiment should be:

1. rebuild the actual EGL shared library path
2. rebuild the host-mode image layer
3. bind-mount just the rebuilt Mesa artifacts into a one-off runtime

Expected: no runtime deployment has happened yet
