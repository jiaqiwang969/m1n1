# Mesa Host-Mode libagxdecode glibc Guard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unblock the Android-target Mesa build on `192.168.1.104` by fixing the `libagxdecode` glibc/bionic feature guard in `decode.c` without changing the working `107` Guest4K baseline.

**Architecture:** Keep the wrapper-based Android cross toolchain unchanged and fix only the next proven source-level blocker. Treat the failing single-object build of `src/asahi/lib/decode.c` as the red test, then narrow the compile-time guard so glibc-only `fopencookie` code is not compiled for Android bionic.

**Tech Stack:** Mesa `meson`/`ninja`, Android cross Clang wrapper, Asahi Gallium driver, remote source tree on `192.168.1.104`

---

### Task 1: Reproduce the Proven Failure

**Files:**
- Test: `/home/dell/redroid-build/mesa-build-android-asahi-llvm15probe-wrapper-zstdpc/src/asahi/lib/libasahi_decode.a.p/decode.c.o`
- Reference: `/home/dell/redroid-build/redroid16-src-cs/external/mesa3d/src/asahi/lib/decode.c`

**Step 1: Run the failing single-target compile**

Run:

```bash
ssh dell@192.168.1.104 \
  'ninja -C /home/dell/redroid-build/mesa-build-android-asahi-llvm15probe-wrapper-zstdpc \
   src/asahi/lib/libasahi_decode.a.p/decode.c.o -v'
```

Expected: FAIL with `cookie_io_functions_t` and `fopencookie` missing.

**Step 2: Capture the precise failing condition**

Run:

```bash
ssh dell@192.168.1.104 \
  'sed -n "1130,1155p" /home/dell/redroid-build/redroid16-src-cs/external/mesa3d/src/asahi/lib/decode.c'
```

Expected: the glibc-only branch is currently guarded by `_GNU_SOURCE`.

### Task 2: Apply the Minimal Root Fix

**Files:**
- Modify: `/home/dell/redroid-build/redroid16-src-cs/external/mesa3d/src/asahi/lib/decode.c`

**Step 1: Replace the incorrect guard**

Change both `#ifdef _GNU_SOURCE` sites around `funcs` and `libagxdecode_init()` to `#ifdef __GLIBC__`.

**Step 2: Keep behavior unchanged on glibc**

Do not change any function body logic, callbacks, or Android wrapper tooling. This task is only about preventing bionic from compiling a glibc-only code path.

### Task 3: Verify the Fix Locally First

**Files:**
- Test: `/home/dell/redroid-build/mesa-build-android-asahi-llvm15probe-wrapper-zstdpc/src/asahi/lib/libasahi_decode.a.p/decode.c.o`

**Step 1: Re-run the same single-target compile**

Run:

```bash
ssh dell@192.168.1.104 \
  'ninja -C /home/dell/redroid-build/mesa-build-android-asahi-llvm15probe-wrapper-zstdpc \
   src/asahi/lib/libasahi_decode.a.p/decode.c.o -v'
```

Expected: PASS, proving the exact blocker is removed.

### Task 4: Advance the Whole Build to the Next Real Blocker

**Files:**
- Test: `/home/dell/redroid-build/mesa-build-android-asahi-llvm15probe-wrapper-zstdpc`

**Step 1: Re-run the full build**

Run:

```bash
ssh dell@192.168.1.104 \
  'ninja -C /home/dell/redroid-build/mesa-build-android-asahi-llvm15probe-wrapper-zstdpc -j4'
```

Expected: either continued progress beyond `decode.c` or a new first failure unrelated to `fopencookie`.

**Step 2: Record the next blocker exactly**

Capture the first `FAILED:` block and add the new evidence to local docs before any further fixes.
