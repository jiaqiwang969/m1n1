# Redroid Asahi Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy a fresh 16K-safe `redroid` image from the x86_64 build host onto the Asahi Linux host and verify Android boots with the new HWC3/minigbm graphics stack.

**Architecture:** Reuse the existing source changes, verify the new graphics binaries are present and 16K-aligned on the build host, regenerate the image artifacts, then import a new container image on the Asahi host from `system.img` and `vendor.img`. Start the container with the known binderfs-before-`/init` pattern and confirm `surfaceflinger`, `vendor.hwcomposer-3`, and `sys.boot_completed`.

**Tech Stack:** AOSP build system, `readelf`, `scp`, `podman`, loop mounts, `adb`, `logcat`

---

### Task 1: Verify Build Outputs On `192.168.1.104`

**Files:**
- Inspect: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/bin/hw/android.hardware.graphics.composer3-service.ranchu`
- Inspect: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/bin/hw/android.hardware.graphics.allocator-service.minigbm`
- Inspect: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/lib64/hw/mapper.minigbm.so`
- Inspect: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/lib64/libOpenglSystemCommon.so`

**Step 1: Check that the expected files exist**

Run:
```bash
ssh dell@192.168.1.104 'ls -l /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/bin/hw/android.hardware.graphics.composer3-service.ranchu /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/bin/hw/android.hardware.graphics.allocator-service.minigbm /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/lib64/hw/mapper.minigbm.so /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/lib64/libOpenglSystemCommon.so'
```
Expected: all four files exist.

**Step 2: Verify ELF load alignment is 16K-safe**

Run:
```bash
ssh dell@192.168.1.104 'for f in /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/bin/hw/android.hardware.graphics.composer3-service.ranchu /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/bin/hw/android.hardware.graphics.allocator-service.minigbm /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/lib64/hw/mapper.minigbm.so /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor/lib64/libOpenglSystemCommon.so; do echo === $f ===; readelf -W -l "$f" | grep LOAD; done'
```
Expected: `LOAD` program headers use `Align 0x4000`.

### Task 2: Build Deployable Images On `192.168.1.104`

**Files:**
- Build output: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/system.img`
- Build output: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor.img`

**Step 1: Regenerate the images**

Run:
```bash
ssh dell@192.168.1.104 'cd /home/dell/redroid-build/redroid16-src-cs && . build/envsetup.sh && lunch redroid_arm64_only-bp2a-userdebug && m systemimage vendorimage -j16'
```
Expected: build exits successfully and refreshes `system.img` and `vendor.img`.

**Step 2: Record file metadata**

Run:
```bash
ssh dell@192.168.1.104 'ls -lh /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/system.img /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor.img'
```
Expected: both images exist with recent timestamps.

### Task 3: Transfer Images To `192.168.1.107`

**Files:**
- Create: `/home/wjq/redroid-artifacts/system.img`
- Create: `/home/wjq/redroid-artifacts/vendor.img`

**Step 1: Copy the images**

Run:
```bash
ssh dell@192.168.1.104 'scp /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/system.img /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only/vendor.img wjq@192.168.1.107:/home/wjq/redroid-artifacts/'
```
Expected: transfer completes without truncation.

**Step 2: Verify hashes on destination**

Run:
```bash
ssh wjq@192.168.1.107 'sha256sum /home/wjq/redroid-artifacts/system.img /home/wjq/redroid-artifacts/vendor.img'
```
Expected: both hashes print successfully.

### Task 4: Import New Container Image On `192.168.1.107`

**Files:**
- Create: `/home/wjq/redroid-artifacts/mnt-system`
- Create: `/home/wjq/redroid-artifacts/mnt-vendor`
- Replace image: `localhost/redroid16k:latest`

**Step 1: Mount and import**

Run:
```bash
ssh wjq@192.168.1.107 'set -e; mkdir -p /home/wjq/redroid-artifacts/mnt-system /home/wjq/redroid-artifacts/mnt-vendor; sudo mount -o loop,ro /home/wjq/redroid-artifacts/system.img /home/wjq/redroid-artifacts/mnt-system; sudo mount -o loop,ro /home/wjq/redroid-artifacts/vendor.img /home/wjq/redroid-artifacts/mnt-vendor; sudo tar --xattrs -C /home/wjq/redroid-artifacts/mnt-vendor -c vendor | tar -C /home/wjq/redroid-artifacts/mnt-system -xf -; sudo tar --xattrs -C /home/wjq/redroid-artifacts/mnt-system -c . | podman import -c '\''ENTRYPOINT ["/init","qemu=1","androidboot.hardware=redroid"]'\'' - localhost/redroid16k:latest; sudo umount /home/wjq/redroid-artifacts/mnt-vendor; sudo umount /home/wjq/redroid-artifacts/mnt-system'
```
Expected: a new image ID is printed and mounts are cleanly released.

**Step 2: Confirm image metadata**

Run:
```bash
ssh wjq@192.168.1.107 'podman image inspect localhost/redroid16k:latest --format "{{.Id}} {{json .Config.Entrypoint}}"'
```
Expected: image exists and entrypoint is `["/init","qemu=1","androidboot.hardware=redroid"]`.

### Task 5: Restart And Verify Runtime On `192.168.1.107`

**Files:**
- Inspect container: `redroid16k`

**Step 1: Recreate the container**

Run:
```bash
ssh wjq@192.168.1.107 'podman rm -f redroid16k >/dev/null 2>&1 || true; podman run -d --name redroid16k --pull=never --privileged --network host --security-opt label=disable --device /dev/kvm -v redroid16k-data:/data --entrypoint /system/bin/sh localhost/redroid16k:latest -c "mkdir -p /dev/binderfs && mount -t binder binder /dev/binderfs && exec /init qemu=1 androidboot.hardware=redroid"'
```
Expected: a new container ID is printed.

**Step 2: Verify boot-critical services**

Run:
```bash
ssh wjq@192.168.1.107 'podman exec redroid16k sh -c "getprop init.svc.surfaceflinger; getprop init.svc.vendor.hwcomposer-3; getprop ro.hardware.gralloc; getprop ro.vendor.hwcomposer.mode; getprop ro.vendor.hwcomposer.display_finder_mode; getprop sys.boot_completed"'
```
Expected: `surfaceflinger` is `running`, `vendor.hwcomposer-3` is `running`, graphics properties match the baked values, and `sys.boot_completed` eventually becomes `1`.

**Step 3: Check logs for graphics failures**

Run:
```bash
ssh wjq@192.168.1.107 'podman exec redroid16k sh -c "logcat -d -b all | grep -E \"surfaceflinger|composer|hwcomposer|gralloc|boot_completed|program alignment\" | tail -n 300"'
```
Expected: no `program alignment (4096) cannot be smaller than system page size (16384)` errors and no repeated `surfaceflinger` crash loop.
