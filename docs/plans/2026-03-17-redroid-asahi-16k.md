# redroid Asahi 16K Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a 16K-capable `redroid_arm64_only` image from source and run it successfully on the Asahi Linux host `wjq@192.168.1.107`.

**Architecture:** Start from `android-16.0.0_r2` plus `remote-android`'s Android 16 `device_redroid` and `redroid-patches`. Apply the minimum product-level 16K/page-agnostic configuration first, build `redroid_arm64_only`, then validate both the artifact internals and runtime behavior on the Asahi host before expanding the patch surface.

**Tech Stack:** AOSP repo/manifest checkout, `remote-android` device tree and patches, containerized Android builder, `podman`, `adb`, `objdump`, `readelf`.

---

### Task 1: Capture The Baseline Failure

**Files:**
- Create: `/home/wjq/redroid16-notes/baseline.txt`
- Validate: existing image `docker.io/redroid/redroid:16.0.0_64only-latest`

**Step 1: Record the current runtime failure**

Run:

```bash
ssh wjq@192.168.1.107 '
  printf "123123\n" | sudo -S podman rm -f redroid 2>/dev/null || true
  printf "123123\n" | sudo -S podman run -d --name redroid \
    --privileged \
    --pull=never \
    --security-opt label=disable \
    -v /var/lib/redroid/data:/data \
    -p 127.0.0.1:5555:5555 \
    --device /dev/binderfs/binder:/dev/binder \
    --device /dev/binderfs/hwbinder:/dev/hwbinder \
    --device /dev/binderfs/vndbinder:/dev/vndbinder \
    docker.io/redroid/redroid:16.0.0_64only-latest \
    androidboot.use_memfd=true
  printf "123123\n" | sudo -S podman ps -a --filter name=redroid
  printf "123123\n" | sudo -S podman logs --tail=100 redroid
' | tee /home/wjq/redroid16-notes/baseline.txt
```

Expected: container exits immediately and logs include `WriteProtected mprotect 1 failed: Invalid argument`.

**Step 2: Record the failing bootstrap constant**

Run:

```bash
ssh wjq@192.168.1.107 '
  tmp=$(mktemp -d)
  tar -xOf /home/wjq/redroid-16.0.0_64only-latest.tar a234387365bc615147261cd5c7dce4747c0b8a2ba678d88e34f2ccfbce69c379.tar |
    tar -xOf - system/lib64/bootstrap/libc.so > "$tmp/libc.so"
  objdump -d --demangle --start-address=0x7adb8 --stop-address=0x7aecc "$tmp/libc.so"
  rm -rf "$tmp"
'
```

Expected: the disassembly shows `mov w1, #0x1000` and related `mprotect` use in `WriteProtected<libc_globals>::initialize()`.

### Task 2: Prepare The Android 16 Source Tree

**Files:**
- Create: `/home/wjq/redroid16/.repo/local_manifests/redroid.xml`
- Create: `/home/wjq/redroid16-builder/` builder clone

**Step 1: Install or verify repo prerequisites**

Run:

```bash
ssh wjq@192.168.1.107 '
  command -v repo || printf "123123\n" | sudo -S dnf install -y git python3 curl java-17-openjdk-devel rsync bc bison flex lz4 perl patch unzip xz which ccache
'
```

Expected: required host tools are present.

**Step 2: Create the source directory**

Run:

```bash
ssh wjq@192.168.1.107 'mkdir -p /home/wjq/redroid16/.repo/local_manifests /home/wjq/redroid16-notes'
```

**Step 3: Initialize AOSP Android 16**

Run:

```bash
ssh wjq@192.168.1.107 '
  cd /home/wjq/redroid16 &&
  repo init -u https://android.googlesource.com/platform/manifest --git-lfs --depth=1 -b android-16.0.0_r2
'
```

Expected: `.repo/manifests` is initialized on `android-16.0.0_r2`.

**Step 4: Write the local manifest**

Create `/home/wjq/redroid16/.repo/local_manifests/redroid.xml` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="redroid" fetch="https://github.com/remote-android/" revision="redroid-16.0.0" />

  <remove-project name="platform/prebuilts/bazel/darwin-x86_64" />
  <remove-project name="platform/prebuilts/clang/host/darwin-x86" />
  <remove-project name="platform/prebuilts/go/darwin-x86" />

  <project path="device/redroid" name="device_redroid" groups="redroid" remote="redroid" />
  <project path="device/redroid-prebuilts" name="device_redroid-prebuilts" groups="redroid" remote="redroid" revision="master" clone-depth="1" />
  <project path="hardware/redroid/c2" name="redroid-c2" groups="redroid" remote="redroid" revision="master" />
  <project path="hardware/redroid/omx" name="redroid-omx" groups="redroid" remote="redroid" revision="master" />
  <project path="vendor/redroid" name="vendor_redroid" groups="redroid" remote="redroid" revision="master" />
</manifest>
```

**Step 5: Sync sources**

Run:

```bash
ssh wjq@192.168.1.107 '
  cd /home/wjq/redroid16 &&
  repo sync -c -j4
'
```

Expected: source tree sync completes with the Android 16 redroid components present.

**Step 6: Fetch and apply redroid patches**

Run:

```bash
ssh wjq@192.168.1.107 '
  rm -rf /home/wjq/redroid-patches &&
  git clone https://github.com/remote-android/redroid-patches.git /home/wjq/redroid-patches &&
  /home/wjq/redroid-patches/apply-patch.sh /home/wjq/redroid16 android-16.0.0_r2
'
```

Expected: Android 16 patch set applies cleanly or reveals the first concrete patch conflict.

### Task 3: Add The Minimal 16K Product Configuration

**Files:**
- Modify: `/home/wjq/redroid16/device/redroid/redroid_arm64_only.mk`
- Optionally modify: `/home/wjq/redroid16/device/redroid/redroid.mk`

**Step 1: Add official AOSP page-size product knobs**

Edit `/home/wjq/redroid16/device/redroid/redroid_arm64_only.mk` to include:

```makefile
PRODUCT_MAX_PAGE_SIZE_SUPPORTED := 16384
PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := true
PRODUCT_NO_BIONIC_PAGE_SIZE_MACRO := true
PRODUCT_16K_DEVELOPER_OPTION := true
```

Place them near the existing product overrides so the setting is target-specific to `redroid_arm64_only`.

**Step 2: Review for any redroid override that reintroduces 4K assumptions**

Run:

```bash
ssh wjq@192.168.1.107 '
  cd /home/wjq/redroid16 &&
  rg -n "4096|PAGE_SIZE|MAX_PAGE_SIZE|NO_BIONIC_PAGE_SIZE_MACRO|16K" device/redroid vendor/redroid build/make/target/product
'
```

Expected: no obvious `device/redroid` override should force the product back to 4K.

**Step 3: Commit the product change in the device repo**

Run:

```bash
ssh wjq@192.168.1.107 '
  cd /home/wjq/redroid16/device/redroid &&
  git status --short &&
  git add redroid_arm64_only.mk &&
  git commit -m "feat: enable 16K page-size config for arm64-only redroid"
'
```

Expected: only the intended product file is committed.

### Task 4: Build redroid_arm64_only

**Files:**
- Validate: `/home/wjq/redroid16/out/target/product/redroid_arm64_only/`

**Step 1: Create or verify the Android builder container**

Use `remote-android/redroid-doc/android-builder-docker` as the builder context. Build it with `podman build` or `docker build` on the Asahi host.

Run:

```bash
ssh wjq@192.168.1.107 '
  rm -rf /home/wjq/redroid-builder-doc &&
  git clone https://github.com/remote-android/redroid-doc.git /home/wjq/redroid-builder-doc &&
  cd /home/wjq/redroid-builder-doc/android-builder-docker &&
  podman build \
    --build-arg userid=$(id -u) \
    --build-arg groupid=$(id -g) \
    --build-arg username=$(id -un) \
    -t redroid-builder .
'
```

Expected: `redroid-builder` image exists locally.

**Step 2: Start the builder container**

Run:

```bash
ssh wjq@192.168.1.107 '
  podman rm -f redroid-builder 2>/dev/null || true
  podman run -d --name redroid-builder --hostname redroid-builder \
    -v /home/wjq/redroid16:/src \
    redroid-builder sleep infinity
'
```

Expected: container remains running.

**Step 3: Configure the build target**

Run:

```bash
ssh wjq@192.168.1.107 '
  podman exec redroid-builder bash -lc "
    cd /src &&
    source build/envsetup.sh &&
    lunch redroid_arm64_only-bp2a-userdebug &&
    get_build_var TARGET_MAX_PAGE_SIZE_SUPPORTED &&
    get_build_var TARGET_NO_BIONIC_PAGE_SIZE_MACRO
  "
'
```

Expected:
- `TARGET_MAX_PAGE_SIZE_SUPPORTED` prints `16384`
- `TARGET_NO_BIONIC_PAGE_SIZE_MACRO` prints `true`

**Step 4: Run the build**

Run:

```bash
ssh wjq@192.168.1.107 '
  podman exec redroid-builder bash -lc "
    cd /src &&
    source build/envsetup.sh &&
    lunch redroid_arm64_only-bp2a-userdebug &&
    m -j$(nproc)
  "
'
```

Expected: build completes and produces `system.img` and `vendor.img`.

**Step 5: If the build fails on prebuilt page-size checks, stop and fix only the named prebuilt**

Run:

```bash
ssh wjq@192.168.1.107 '
  cd /home/wjq/redroid16 &&
  rg -n "max page size|prebuilt.*page|16384|4096" out/soong.log out/error.log 2>/dev/null || true
'
```

Expected: either no hits, or a narrow list of incompatible prebuilts to address.

### Task 5: Validate The Built Artifact Before Runtime

**Files:**
- Validate: `/home/wjq/redroid16/out/target/product/redroid_arm64_only/system.img`

**Step 1: Extract bootstrap libc and inspect it**

Run:

```bash
ssh wjq@192.168.1.107 '
  tmp=$(mktemp -d)
  cd /home/wjq/redroid16/out/target/product/redroid_arm64_only
  mkdir -p "$tmp/system"
  printf "123123\n" | sudo -S mount -o loop,ro system.img "$tmp/system"
  cp "$tmp/system/system/lib64/bootstrap/libc.so" "$tmp/libc.so"
  printf "123123\n" | sudo -S umount "$tmp/system"
  objdump -d --demangle --start-address=0x0 --stop-address=0x900000 "$tmp/libc.so" | grep -n "WriteProtected<libc_globals>::initialize" -A30
  rm -rf "$tmp"
'
```

Expected: the disassembly should no longer show the previous `0x1000` hardcoding in the failing path.

**Step 2: Check ELF segment alignment**

Run:

```bash
ssh wjq@192.168.1.107 '
  tmp=$(mktemp -d)
  cd /home/wjq/redroid16/out/target/product/redroid_arm64_only
  mkdir -p "$tmp/system"
  printf "123123\n" | sudo -S mount -o loop,ro system.img "$tmp/system"
  readelf -l "$tmp/system/system/bin/init" | sed -n "1,40p"
  readelf -l "$tmp/system/system/lib64/bootstrap/libc.so" | sed -n "1,40p"
  printf "123123\n" | sudo -S umount "$tmp/system"
  rm -rf "$tmp"
'
```

Expected: `Align` values are compatible with a `16384` max page-size build.

### Task 6: Import And Run The Built Image On Asahi

**Files:**
- Create: `/home/wjq/redroid16-image.tar`
- Validate: imported image `localhost/redroid16-asahi:dev`

**Step 1: Import the built images as a container image**

Run:

```bash
ssh wjq@192.168.1.107 '
  cd /home/wjq/redroid16/out/target/product/redroid_arm64_only &&
  rm -rf system vendor &&
  mkdir system vendor &&
  printf "123123\n" | sudo -S mount -o loop,ro system.img system &&
  printf "123123\n" | sudo -S mount -o loop,ro vendor.img vendor &&
  printf "123123\n" | sudo -S tar --xattrs -c vendor -C system --exclude="./vendor" . |
    podman import -c '\''ENTRYPOINT ["/init","qemu=1","androidboot.hardware=redroid"]'\'' - localhost/redroid16-asahi:dev &&
  printf "123123\n" | sudo -S umount system vendor
'
```

Expected: `localhost/redroid16-asahi:dev` appears in `podman images`.

**Step 2: Load into the rootful podman store**

Run:

```bash
ssh wjq@192.168.1.107 '
  podman save -o /home/wjq/redroid16-image.tar localhost/redroid16-asahi:dev &&
  printf "123123\n" | sudo -S podman load -i /home/wjq/redroid16-image.tar
'
```

Expected: the image is available to `sudo podman`.

**Step 3: Run the image**

Run:

```bash
ssh wjq@192.168.1.107 '
  printf "123123\n" | sudo -S mkdir -p /var/lib/redroid16/data
  printf "123123\n" | sudo -S podman rm -f redroid16 2>/dev/null || true
  printf "123123\n" | sudo -S podman run -d --name redroid16 \
    --privileged \
    --pull=never \
    --security-opt label=disable \
    -v /var/lib/redroid16/data:/data \
    -p 127.0.0.1:5555:5555 \
    --device /dev/binderfs/binder:/dev/binder \
    --device /dev/binderfs/hwbinder:/dev/hwbinder \
    --device /dev/binderfs/vndbinder:/dev/vndbinder \
    localhost/redroid16-asahi:dev \
    androidboot.use_memfd=true \
    androidboot.redroid_width=1080 \
    androidboot.redroid_height=1920 \
    androidboot.redroid_dpi=480
  printf "123123\n" | sudo -S podman ps -a --filter name=redroid16
  printf "123123\n" | sudo -S podman logs --tail=200 redroid16
'
```

Expected: the container stays `Up`, not `Exited (127)`.

### Task 7: Verify adb And Basic Runtime Health

**Files:**
- Validate: running container `redroid16`

**Step 1: Connect with adb from the Asahi host**

Run:

```bash
ssh wjq@192.168.1.107 '
  adb connect 127.0.0.1:5555 &&
  adb devices -l
'
```

Expected: one online device at `127.0.0.1:5555`.

**Step 2: Confirm Android properties**

Run:

```bash
ssh wjq@192.168.1.107 '
  adb -s 127.0.0.1:5555 shell getprop ro.product.model
  adb -s 127.0.0.1:5555 shell getprop ro.build.version.release_or_codename
  adb -s 127.0.0.1:5555 shell getprop ro.secure
'
```

Expected: Android properties return from the new source-built instance.

**Step 3: Capture final evidence**

Run:

```bash
ssh wjq@192.168.1.107 '
  printf "123123\n" | sudo -S podman logs --tail=200 redroid16 > /home/wjq/redroid16-notes/final-redroid16.log
  adb -s 127.0.0.1:5555 shell getprop > /home/wjq/redroid16-notes/final-getprop.txt
'
```

Expected: final runtime evidence is stored under `/home/wjq/redroid16-notes/`.
