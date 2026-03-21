# Redroid Host-Mode Mesa Runtime Delivery Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Safely validate the rebuilt Android-target Mesa stack on `192.168.1.107` without destabilizing the working `Guest4K` mainline.

**Architecture:** Treat `/home/dell/redroid-build/mesa-hostmode-overlay-stage2-20260321` on `192.168.1.104` as the only candidate runtime bundle. First verify how the legacy direct-host container is launched on `107`, then run a one-off host-mode experiment using file-level overlay injection or a scratch image layer. Do not replace the default operator flow until fresh runtime logs prove the new stack is usable.

**Tech Stack:** `ssh`, `scp`, `podman`, Redroid direct-host container, Android `logcat`, ELF `readelf`

---

### Task 1: Freeze the candidate overlay inputs

**Files:**
- Inspect: `/home/dell/redroid-build/mesa-hostmode-overlay-stage2-20260321/README.txt`
- Inspect: `/home/dell/redroid-build/mesa-hostmode-overlay-stage2-20260321.tar.gz`
- Inspect: `/home/dell/redroid-build/mesa-hostmode-overlay-stage2-20260321.tar.gz.sha256`

**Step 1: Verify the archive checksum on `104`**

Run:

```bash
ssh dell@192.168.1.104 \
  "cd /home/dell/redroid-build && sha256sum -c mesa-hostmode-overlay-stage2-20260321.tar.gz.sha256"
```

Expected: `OK`

**Step 2: Re-check the key staged ELF metadata before transfer**

Run:

```bash
ssh dell@192.168.1.104 \
  "readelf -d /home/dell/redroid-build/mesa-hostmode-overlay-stage2-20260321/vendor/lib64/egl/libEGL_mesa.so \
   | egrep 'SONAME|NEEDED|RUNPATH|RPATH'"
```

Expected:

- `SONAME` is `libEGL_mesa.so.1`
- `NEEDED` contains `libgallium_dri.so`
- `NEEDED` contains `libglapi.so.0`
- no `RUNPATH`

### Task 2: Capture the current `107` host-mode launch shape

**Files:**
- Inspect: current direct-host launch script or shell history on `107`
- Inspect: current container/image metadata on `107`

**Step 1: Find the exact container/image used for the legacy direct-host path**

Run:

```bash
ssh wjq@192.168.1.107 \
  "podman ps -a --format '{{.Names}} {{.Image}}' | grep redroid"
```

Expected: the legacy direct-host container/image pair is identified explicitly

**Step 2: Capture the actual mount and command-line shape**

Run:

```bash
ssh wjq@192.168.1.107 \
  "podman inspect redroid16k-root-safe --format '{{json .Mounts}}' && \
   echo === && \
   podman inspect redroid16k-root-safe --format '{{json .Config.Cmd}}'"
```

Expected: exact injection points for `/vendor/lib64/...` become clear

### Task 3: Choose the smallest safe delivery mechanism

**Files:**
- Create temporarily on `107`: `/tmp/mesa-hostmode-overlay-stage2-20260321`

**Step 1: Transfer the tarball to `107`**

Run:

```bash
scp dell@192.168.1.104:/home/dell/redroid-build/mesa-hostmode-overlay-stage2-20260321.tar.gz \
  /tmp/mesa-hostmode-overlay-stage2-20260321.tar.gz
scp /tmp/mesa-hostmode-overlay-stage2-20260321.tar.gz \
  wjq@192.168.1.107:/tmp/
```

Expected: archive arrives on `107`

**Step 2: Unpack to a scratch directory**

Run:

```bash
ssh wjq@192.168.1.107 \
  "rm -rf /tmp/mesa-hostmode-overlay-stage2-20260321 && \
   mkdir -p /tmp/mesa-hostmode-overlay-stage2-20260321 && \
   tar -xzf /tmp/mesa-hostmode-overlay-stage2-20260321.tar.gz -C /tmp"
```

Expected: staged files are visible on `107`

**Step 3: Prefer file-level injection first**

Use one of:

1. individual `-v hostfile:containerfile:ro` mounts for the six Mesa files plus `libzstd.so`
2. a scratch derived image layer if file-level mounts are too awkward

Expected: no existing working operator script is overwritten yet

### Task 4: Run one host-mode proof boot

**Files:**
- Runtime logs only

**Step 1: Boot a one-off direct-host container using the staged Mesa overlay**

Run: a dedicated `podman run` or copied launcher with:

- existing direct-host volume/data settings
- host-mode graphics flags
- staged Mesa file injections under `/vendor/lib64/...`

Expected: container reaches early boot

**Step 2: Capture the first discriminating runtime logs**

Run:

```bash
ssh wjq@192.168.1.107 \
  "adb -s 127.0.0.1:5555 shell logcat -d | grep -iE 'mesa|egl|dri|gralloc|imapper|surfaceflinger|hwcomposer' | tail -200"
```

Expected: one of the following becomes explicit:

- Mesa now opens a real DRM path and progresses past fallback gralloc
- or the next blocker becomes a clean linker/runtime issue such as `libzstd.so` visibility
- or a later graphics init failure replaces the earlier `failed to create dri2 screen`

### Task 5: Stop after the first clean runtime verdict

**Files:**
- Update: local docs only after evidence is captured

**Step 1: Do not iterate fixes blindly on `107`**

If the boot fails, stop after the first clear failure class and record:

- exact missing library or namespace denial
- exact EGL/DRI/HWC error
- whether the IMapper fallback is gone

Expected: the next round starts from one proven runtime blocker, not a bundle of guesses
