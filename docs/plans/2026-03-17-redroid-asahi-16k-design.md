# redroid On Asahi 16K Design

**Goal**

Build and run a source-built `redroid_arm64_only` image on the Asahi Linux host `wjq@192.168.1.107`, with the minimum changes required for a 16 KB page-size host.

**Problem Summary**

The published image `redroid/redroid:16.0.0_64only-latest` exits immediately on the Asahi host. The host kernel uses `16384`-byte pages, and the image's bootstrap `libc.so` was built with `0x1000` page-size assumptions in `WriteProtected<libc_globals>::initialize()`. On this host, that causes an early `mprotect(...)=EINVAL` and the container exits before Android finishes booting.

**Evidence**

- Host page size: `getconf PAGESIZE` on `192.168.1.107` returns `16384`.
- Official image failure: `WriteProtected mprotect 1 failed: Invalid argument`.
- Disassembly of the published Android 16 image showed `memset`/`mprotect` calls using `0x1000` inside bootstrap `libc.so`.
- AOSP exposes official product-level controls for larger/page-agnostic builds:
  - `PRODUCT_MAX_PAGE_SIZE_SUPPORTED`
  - `PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE`
  - `PRODUCT_NO_BIONIC_PAGE_SIZE_MACRO`
  - `PRODUCT_16K_DEVELOPER_OPTION`

**Recommended Approach**

Use `AOSP android-16.0.0_r2` as the base, layer `remote-android`'s `device_redroid` and `redroid-patches/android-16.0.0_r2` on top, then make the smallest product-level change necessary to build a 16K-capable `redroid_arm64_only` target.

This keeps us close to upstream `redroid` 16 and avoids a risky fork of bionic or ART unless the first build proves a deeper incompatibility.

**Architecture**

1. Build only `arm64 only`.
   The Asahi host is `aarch64`, and the current requirement is simply to boot `redroid` on that machine. Avoiding 32-bit secondary arch reduces build surface and prebuilt risk.

2. Start with product configuration, not framework surgery.
   The first change should be in `device/redroid/redroid_arm64_only.mk` or a product file it inherits. Set the official page-size product variables there so Soong/Make propagate the correct max supported page size and disable reliance on bionic's compile-time `PAGE_SIZE` macro where required.

3. Keep `redroid` patches unchanged unless the build or boot proves otherwise.
   The current known failure occurs before Android userspace fully boots, so changing `device_redroid` product configuration is the least invasive first step. If that produces a 16K-correct bootstrap `libc.so`, we test before touching `redroid-patches`.

4. Validate in two stages.
   First validate the built artifact itself by extracting `system/lib64/bootstrap/libc.so` and confirming the `0x1000` assumption is gone. Then import the image into `sudo podman` on Asahi and verify the container stays up and exposes `adb`.

**Alternatives Considered**

1. Patch the published image binaries in place.
   Rejected because it is brittle, hard to maintain, and likely to miss other 4K assumptions.

2. Make a fully page-agnostic fork immediately.
   Rejected for the first pass because it broadens the change set before we know whether the official Android 16 product knobs already solve the actual failure.

3. Switch to another Android runtime.
   Rejected because the explicit requirement is to run `redroid` on Asahi.

**Implementation Boundaries**

- In scope:
  - Source checkout
  - Builder environment
  - `device/redroid` product configuration
  - Building `redroid_arm64_only`
  - Importing and running the image on `192.168.1.107`
  - `adb` connectivity verification

- Out of scope:
  - Assisting with bypassing third-party login flows
  - Reproducing private app login APIs
  - Anti-debug or auth-token bypass work

**Risks**

- `209G` free space may be tight for a full Android 16 build tree plus `out/`; we will monitor usage and prune caches if needed.
- Some prebuilt artifacts in `device_redroid-prebuilts` may fail the 16K page-size check and require replacement or selective disabling.
- If product-level configuration is insufficient, we may need a second pass in `redroid-patches` or specific upstream modules.

**Success Criteria**

1. The built bootstrap `libc.so` no longer hardcodes `0x1000` for the failing `WriteProtected` path.
2. `sudo podman run ... redroid` remains running on `192.168.1.107`.
3. `adb connect 127.0.0.1:5555` succeeds from the Asahi host.
4. `adb shell getprop ro.product.model` returns the custom `redroid16_arm64_only` product or equivalent running Android properties.
