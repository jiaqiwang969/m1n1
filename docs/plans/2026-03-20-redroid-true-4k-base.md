# Redroid True 4K Base Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Produce a true 4 KB Redroid image, import it as a separate container image, and validate it through the existing Guest4K workflow without breaking the current 16 KB baseline.

**Architecture:** Add a new Redroid arm64-only 4 KB product variant on the build host, build separate `system.img` and `vendor.img` outputs for it, import those outputs on the Asahi host as `localhost/redroid4k-root:latest`, then run the existing Guest4K operator against that image. Keep the current 16 KB image, scripts, and containers intact unless a later pass explicitly promotes the 4 KB image to default.

**Tech Stack:** AOSP product makefiles, `lunch`, `m`, `scp`, `podman`, loop mounts, `adb`, `logcat`, `zsh`, Markdown

---

### Task 1: Reconfirm the current architecture boundary

**Files:**
- Inspect: `/home/dell/redroid-build/redroid16-src-cs/device/redroid/redroid_arm64_only.mk`
- Inspect: `/home/dell/redroid-build/redroid16-src-cs/device/redroid/AndroidProducts.mk`
- Inspect: [2026-03-20-redroid-guest4k-root-cause.md](/Users/jqwang/25-红手指手机/m1n1/docs/plans/2026-03-20-redroid-guest4k-root-cause.md)

**Step 1: Verify the current product is still 16 KB**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 \
  "grep -n 'PRODUCT_MAX_PAGE_SIZE_SUPPORTED' /home/dell/redroid-build/redroid16-src-cs/device/redroid/redroid_arm64_only.mk"
```

Expected: `PRODUCT_MAX_PAGE_SIZE_SUPPORTED := 16384`

**Step 2: Verify no dedicated 4 KB lunch target exists yet**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 \
  "grep -n 'redroid_arm64_only_4k' /home/dell/redroid-build/redroid16-src-cs/device/redroid/AndroidProducts.mk || true"
```

Expected: no output

**Step 3: Verify the current runtime image still self-reports 16 KB**

Run:

```bash
sshpass -p 123123 ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  'ssh -o StrictHostKeyChecking=no -i /home/wjq/vm4k/ubuntu24k/guest_key -p 2222 wjq@127.0.0.1 \
   "printf \"123123\n\" | sudo -S -p \"\" podman exec redroid16kguestprobe /system/bin/sh -c \"getprop ro.product.cpu.pagesize.max\""' 
```

Expected: `16384`

### Task 2: Add the 4 KB product variant on the build host

**Files:**
- Create: `/home/dell/redroid-build/redroid16-src-cs/device/redroid/redroid_arm64_only_4k.mk`
- Create: `/home/dell/redroid-build/redroid16-src-cs/device/redroid/redroid_arm64_only_4k/BoardConfig.mk`
- Create: `/home/dell/redroid-build/redroid16-src-cs/device/redroid/redroid_arm64_only_4k/device.mk`
- Modify: `/home/dell/redroid-build/redroid16-src-cs/device/redroid/AndroidProducts.mk`

**Step 1: Prove the new lunch target does not exist yet**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 \
  'bash --login -c "cd /home/dell/redroid-build/redroid16-src-cs && source build/envsetup.sh >/dev/null 2>&1 && lunch redroid_arm64_only_4k-bp2a-userdebug"'
```

Expected: FAIL because the product does not exist yet

**Step 2: Create the new product file**

Implement a new product that reuses the current Redroid arm64-only stack but changes the page-size policy:

- `PRODUCT_NAME := redroid_arm64_only_4k`
- `PRODUCT_DEVICE := redroid_arm64_only_4k`
- `PRODUCT_MODEL := redroid16_arm64_only_4k`
- `PRODUCT_MAX_PAGE_SIZE_SUPPORTED := 4096`
- do not carry the current 16 KB-only assumptions forward blindly
- if required for first build bring-up, relax prebuilt max-page-size enforcement only in this 4 KB variant

Note:

- If `PRODUCT_DEVICE := redroid_arm64_only_4k`, AOSP will also look for `device/.../redroid_arm64_only_4k/BoardConfig.mk`
- so a minimal wrapper device directory is required to preserve a dedicated `PRODUCT_OUT` path such as `out/target/product/redroid_arm64_only_4k`
- the wrapper `BoardConfig.mk` and `device.mk` can include the existing `redroid_arm64_only` definitions for first bring-up

**Step 3: Register the new lunch choice**

Add the new makefile and lunch target to `AndroidProducts.mk`.

**Step 4: Verify the new lunch target resolves**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 \
  'bash --login -c "cd /home/dell/redroid-build/redroid16-src-cs && source build/envsetup.sh >/dev/null 2>&1 && lunch redroid_arm64_only_4k-bp2a-userdebug >/tmp/redroid4k_lunch.log && cat /tmp/redroid4k_lunch.log"'
```

Expected: lunch succeeds

### Task 3: Verify the new product variables before the full build

**Files:**
- Inspect: `/home/dell/redroid-build/redroid16-src-cs/device/redroid/redroid_arm64_only_4k.mk`

**Step 1: Check `TARGET_MAX_PAGE_SIZE_SUPPORTED`**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 \
  'bash --login -c "cd /home/dell/redroid-build/redroid16-src-cs && source build/envsetup.sh >/dev/null 2>&1 && lunch redroid_arm64_only_4k-bp2a-userdebug >/dev/null && get_build_var TARGET_MAX_PAGE_SIZE_SUPPORTED"'
```

Expected: `4096`

**Step 2: Check the bionic page-size macro mode**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 \
  'bash --login -c "cd /home/dell/redroid-build/redroid16-src-cs && source build/envsetup.sh >/dev/null 2>&1 && lunch redroid_arm64_only_4k-bp2a-userdebug >/dev/null && get_build_var TARGET_NO_BIONIC_PAGE_SIZE_MACRO"'
```

Expected: the value matches the intended 4 KB product policy and is not accidentally inheriting the old forced-16 KB setting

**Step 3: Record the output directory**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 \
  'bash --login -c "cd /home/dell/redroid-build/redroid16-src-cs && source build/envsetup.sh >/dev/null 2>&1 && lunch redroid_arm64_only_4k-bp2a-userdebug >/dev/null && get_build_var PRODUCT_OUT"'
```

Expected: a dedicated output directory such as `.../out/target/product/redroid_arm64_only_4k`

### Task 4: Build the new 4 KB images

**Files:**
- Build output: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only_4k/system.img`
- Build output: `/home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only_4k/vendor.img`

**Step 1: Build `systemimage` and `vendorimage`**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 \
  'bash --login -c "cd /home/dell/redroid-build/redroid16-src-cs && source build/envsetup.sh && lunch redroid_arm64_only_4k-bp2a-userdebug && m systemimage vendorimage -j16"'
```

Expected: build succeeds

**Step 2: Verify the images exist**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 \
  "ls -lh /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only_4k/system.img /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only_4k/vendor.img"
```

Expected: both images exist with fresh timestamps

**Step 3: Verify the built property file says 4 KB**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 \
  "grep '^ro.product.cpu.pagesize.max=' /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only_4k/system/build.prop"
```

Expected: `ro.product.cpu.pagesize.max=4096`

### Task 5: Transfer and import the new image on the Asahi host

**Files:**
- Create: `/home/wjq/redroid-artifacts/4k/system.img`
- Create: `/home/wjq/redroid-artifacts/4k/vendor.img`
- Create: `/home/wjq/redroid-artifacts/4k/mnt-system`
- Create: `/home/wjq/redroid-artifacts/4k/mnt-vendor`
- Create image: `localhost/redroid4k-root:latest`

**Step 1: Copy the images to the Asahi host**

Run:

```bash
sshpass -p 123123 ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  "mkdir -p /home/wjq/redroid-artifacts/4k"

sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 \
  "scp /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only_4k/system.img /home/dell/redroid-build/redroid16-src-cs/out/target/product/redroid_arm64_only_4k/vendor.img wjq@192.168.1.107:/home/wjq/redroid-artifacts/4k/"
```

Expected: transfer completes

**Step 2: Import a separate Podman image**

Run:

```bash
sshpass -p 123123 ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  "printf '%s\n' '123123' | sudo -S -p '' bash -lc 'set -e; mkdir -p /home/wjq/redroid-artifacts/4k/mnt-system /home/wjq/redroid-artifacts/4k/mnt-vendor; mount -o loop,ro /home/wjq/redroid-artifacts/4k/system.img /home/wjq/redroid-artifacts/4k/mnt-system; mount -o loop,ro /home/wjq/redroid-artifacts/4k/vendor.img /home/wjq/redroid-artifacts/4k/mnt-vendor; tar --xattrs -C /home/wjq/redroid-artifacts/4k/mnt-vendor -c vendor | tar -C /home/wjq/redroid-artifacts/4k/mnt-system -xf -; tar --xattrs -C /home/wjq/redroid-artifacts/4k/mnt-system -c . | podman import -c '\''ENTRYPOINT [\"/init\",\"qemu=1\",\"androidboot.hardware=redroid\"]'\'' - localhost/redroid4k-root:latest; umount /home/wjq/redroid-artifacts/4k/mnt-vendor; umount /home/wjq/redroid-artifacts/4k/mnt-system'"
```

Expected: Podman prints a new image ID for `localhost/redroid4k-root:latest`

**Step 3: Verify the imported image still says 4 KB**

Run:

```bash
sshpass -p 123123 ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  "printf '%s\n' '123123' | sudo -S -p '' podman run --rm --pull=never --entrypoint /system/bin/sh localhost/redroid4k-root:latest -c \"grep '^ro.product.cpu.pagesize.max=' /system/build.prop\""
```

Expected: `ro.product.cpu.pagesize.max=4096`

### Task 6: Launch the true-4K image through the existing Guest4K operator

**Files:**
- Validate: [redroid_guest4k_107.sh](/Users/jqwang/25-红手指手机/m1n1/redroid/scripts/redroid_guest4k_107.sh)

**Step 1: Restart Guest4K against the new image**

Run:

```bash
export SUDO_PASS=123123
IMAGE=localhost/redroid4k-root:latest zsh redroid/scripts/redroid_guest4k_107.sh restart
```

Expected: the guest container is recreated using `localhost/redroid4k-root:latest`

**Step 2: Check early runtime state**

Run:

```bash
sshpass -p 123123 ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  'ssh -o StrictHostKeyChecking=no -i /home/wjq/vm4k/ubuntu24k/guest_key -p 2222 wjq@127.0.0.1 \
   "printf \"123123\n\" | sudo -S -p \"\" podman exec redroid16kguestprobe /system/bin/sh -c \"getprop ro.product.cpu.pagesize.max; getprop init.svc.surfaceflinger; getprop init.svc.vendor.graphics.allocator; getprop sys.boot_completed\""' 
```

Expected:
- `ro.product.cpu.pagesize.max=4096`
- the service state reveals whether the new 4 KB image advances farther than the old mixed-mode path

**Step 3: Collect the first truthful failure boundary if boot is still incomplete**

Run:

```bash
sshpass -p 123123 ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  'ssh -o StrictHostKeyChecking=no -i /home/wjq/vm4k/ubuntu24k/guest_key -p 2222 wjq@127.0.0.1 \
   "printf \"123123\n\" | sudo -S -p \"\" podman exec redroid16kguestprobe logcat -d 2>/dev/null | tail -n 400"'
```

Expected: logs now reflect the true 4 KB Android base rather than the old mixed 16K-image-on-4K-guest contradiction

### Task 7: Update local documentation after the first true-4K validation

**Files:**
- Modify: [README.md](/Users/jqwang/25-红手指手机/m1n1/README.md)
- Modify: [install-china-apps.md](/Users/jqwang/25-红手指手机/m1n1/docs/guides/install-china-apps.md)
- Modify: [2026-03-20-redroid-guest4k-root-cause.md](/Users/jqwang/25-红手指手机/m1n1/docs/plans/2026-03-20-redroid-guest4k-root-cause.md)

**Step 1: Update the image naming and status language**

Document:

- the new 4 KB product name
- the new imported image tag
- whether it boots fully, partially, or fails at a new boundary

**Step 2: Keep the 16 KB baseline explicitly separate**

Document that:

- `localhost/redroid16k-root:latest` remains the stable 16 KB baseline
- `localhost/redroid4k-root:latest` is the new true-4K experimental line

**Step 3: Re-run local doc sanity checks**

Run:

```bash
rg -n "redroid4k-root|redroid_arm64_only_4k|true 4 KB|4 KB Android base" README.md docs
```

Expected: the new terminology is consistent and does not overwrite the old 16 KB baseline history
