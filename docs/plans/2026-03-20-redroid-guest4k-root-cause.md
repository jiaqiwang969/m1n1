# Redroid Guest4K Root-Cause Update

## Goal

Explain why Guest4K originally stalled at `HWC did not hotplug`, and record the source-level fix that made the `4K` guest Android 16 runtime boot successfully.

## Final Outcome

The Guest4K runtime now boots successfully.

Confirmed live state inside the guest Redroid container:

- `init.svc.vendor.hwcomposer-3=running`
- `init.svc.surfaceflinger=running`
- `sys.boot_completed=1`

This means the earlier SurfaceFlinger boot loop has been broken at the root, not bypassed with a one-off runtime hack.

## March 20 Card-First + Drop-Master Completion

The earlier minigbm experiment is no longer just a partial result.

The current remote source tree on `dell@192.168.1.104` now contains both:

- software-rendering `card-first` DRM node selection
- `drmDropMaster()` on card-node init opens via
  `external/minigbm/cros_gralloc/cros_gralloc_drm_master_utils.h`

Those rebuilt artifacts were copied into a new guest image tag on `wjq@192.168.1.107`:

- `localhost/redroid4k-root:minigbm-dropmaster`

Live proof from that image:

- the guest container is running the rebuilt hashes:
  - `9d005935...` `android.hardware.graphics.allocator-service.minigbm`
  - `87ccca00...` `libminigbm_gralloc.so`
  - `514af1c1...` `mapper.minigbm.so`
- host-side boot proof:
  - `sys.boot_completed=1`
  - `ro.boot.use_redroid_vnc=1`
  - `127.0.0.1:5901 -> RFB 003.008`
- runtime fd proof:
  - `surfaceflinger` now holds `/dev/dri/card0`
- UI proof:
  - `am start -W -n com.android.settings/.homepage.SettingsHomepageActivity`
    returned `Status: ok`
  - `dumpsys activity activities` showed:
    `topResumedActivity=...SettingsHomepageActivity`

Fresh log tail from that successful repro no longer contained:

- `DRM_IOCTL_MODE_CREATE_DUMB failed`
- `Failed to create bo`
- `GraphicBufferAllocator: Failed to allocate`
- `drawRenderNode called on a context with no surface`
- `failed to get master drm device`
- `HWC did not hotplug`

That changes the project conclusion:

- node-order alone was not enough
- node-order plus immediate master drop on card-node init opens is enough for the current Guest4K
  Settings repro
- the base Guest4K graphics bring-up is now in the "working" category, not the "suspected but
  unproven" category

## March 20 Minigbm Experiment Update

A later experiment tested a new source-level minigbm repair in
`external/minigbm/cros_gralloc/cros_gralloc_driver.cc`:

- when software rendering is active (`ro.hardware.vulkan=pastel`)
- prefer probing `card*` nodes before `renderD*` nodes

That experiment is now part of the project record because it changed the failure shape in a meaningful way.

Confirmed facts from that run:

- the helper was added test-first and the host gtest passed on the build host
- the patched `libminigbm_gralloc.so` was injected into the live Guest4K container and its new hash was
  confirmed inside `/vendor/lib64/libminigbm_gralloc.so`
- once that patched library was active, the old allocator-driven UI crash signature stopped being the
  first visible blocker

The previous signature was:

- `DRM_IOCTL_MODE_CREATE_DUMB failed`
- `android.hardware.graphics.allocator-service.minigbm: Failed to create bo`
- `GraphicBufferAllocator: Failed to allocate`
- `drawRenderNode called on a context with no surface!`

With the patched minigbm live, the new first blocker became:

- `SurfaceFlinger: Initial display configuration failed: HWC did not hotplug`

Interpretation:

- the Guest4K graphics problem is layered
- the minigbm node-selection repair appears to unblock the earlier allocator failure
- but the next blocker is now the HWC/display initialization path

Operational note:

- the local operator script was later corrected so it now waits for a real VNC `RFB` banner instead of
  the empty `init.svc.vendor.vncserver` property
- the operator script now also passes `androidboot.use_redroid_vnc=1` during Guest4K restart

## March 20 Minigbm Follow-Up Instrumentation

The next experiment did not guess at a fix. It added narrow HWC-side diagnostics and re-ran the
patched-minigbm boot once.

Confirmed facts from that run:

- the patched Guest4K runtime really was live:
  - `/vendor/bin/hw/android.hardware.graphics.composer3-service.ranchu`
  - `/vendor/lib64/libminigbm_gralloc.so`
  both showed the new injected hashes inside the guest container
- `InspectDrmNode()` still saw a usable display candidate on `/dev/dri/card0`:
  - driver `virtio_gpu`
  - `connector[0] connected=1`
  - `crtcs=1`
  - `planes=2`
- the later failure was earlier than `findDrmDisplays()` itself:
  - `RanchuHwc: init: failed to get master drm device`
- after that failed init, repeated retries naturally reported:
  - `getDisplayConfigs: tracking 0 DRM displays`
  - `findDrmDisplays: drm returned 0 display configs`
  - `SurfaceFlinger: Initial display configuration failed: HWC did not hotplug`

An additional runtime check inside the guest showed that the HWC service process held two open file
descriptors for `/dev/dri/card0`.

The next instrumentation pass proved where the conflict appears:

- at `LogSelfDrmFds("init-start")`, the process already held:
  - `fd=6 -> /dev/dri/card0`
  - `isMaster=1`
- at `LogSelfDrmFds("openpreferred-after-open")`, the later HWC open created:
  - `fd=7 -> /dev/dri/card0`
  - `isMaster=0`
- `OpenPreferredDrmFd()` then returned `fd=7`
- `drmSetMaster(fd=7)` failed with:
  - `ret=-1`
  - `errno=13`
  - `isMasterAfterSet=0`

Inference from those facts is now narrower:

- the node-order repair did not just "move the error message"
- the earlier master-owning `/dev/dri/card0` fd already exists before `DrmClient::init()` starts
- because DRM master is fd-scoped, the later HWC fd never becomes master, and display
  initialization collapses into the observed `0 DRM displays` state
- the remaining open question is only the identity of the earlier opener
- because this behavior appears only in the card-first minigbm experiment, the strongest current
  inference is still that minigbm's earlier primary-node path creates `fd=6`

## The Real Failure Chain

The earlier visible symptom was:

- `Initial display configuration failed: HWC did not hotplug`

That was only the last symptom in the chain. The deeper sequence was:

1. `android.hardware.graphics.composer3-service.ranchu` was running in DRM display-finder mode.
2. `findDrmDisplays()` kept returning `0 display configs`.
3. SurfaceFlinger never saw an initial display and restarted in a loop.

Source-level instrumentation then showed the key detail:

- candidate DRM nodes were being inspected before `DRM_CLIENT_CAP_UNIVERSAL_PLANES` was enabled on the candidate file descriptor
- as a result, candidate nodes were observed as having `planes=0`
- nodes with `planes=0` were rejected as unusable display pipelines

This made the HWC service reject both:

- `vkms` inside the earlier `guest-vkms` mapping
- `virtio_gpu` when the full `/dev/dri` tree was exposed

## What Was Fixed

Two changes mattered.

### 1. Stop using the `guest-vkms` shape as the mainline runtime

The stable runtime shape is now:

- `16K` Asahi host
- `4K` microVM guest
- full `/dev/dri` exposed inside the guest Redroid container
- isolated guest container networking with published ports

That allows HWC to see both guest DRM candidates:

- `/dev/dri/card0` -> `vkms`
- `/dev/dri/card1` -> `virtio_gpu`

### 2. Fix HWC DRM node inspection

In `device/generic/goldfish-opengl/system/hwc3/DrmClient.cpp`, the candidate DRM fd now enables:

- `DRM_CLIENT_CAP_UNIVERSAL_PLANES`

before `drmModeGetPlaneResources()` is queried during candidate inspection.

That changes candidate detection from a false `planes=0` result into a usable display pipeline.

## Live Proof

After the fix, the startup log changed from "no usable DRM node" to:

- `selected DRM device /dev/dri/card1 (virtio_gpu)`
- `findDrmDisplays: drm returned 1 display configs`
- `findDrmDisplays: display id=0 1280x800 dpi=100x100 rr=75`
- `createDisplaysLocked: creating 1 initial displays`

This is the evidence that actually matters. It proves that:

- HWC now selects a usable DRM node
- SurfaceFlinger gets a real initial display
- the Guest4K Android runtime can complete boot

## What This Means For The Project

The project is no longer blocked on "can a true 4K Android base boot on this machine?" That step is now proven.

The current mainline should therefore be:

- Guest4K runtime for ongoing Android and China-app work

The old direct-host `16K` route still has value, but only as:

- a legacy automation surface
- a comparison baseline
- a place where older `douyin-compat` / `phone-mode` / `libtnet` helper actions still exist

## Practical Next Step

Now that the base Guest4K runtime is stable with the patched image, the next useful work is no longer
graphics bring-up itself.

The next step should be:

1. promote the rebuilt graphics stack into a reproducible default Guest4K image flow
2. trim or remove the temporary `redroid-minigbm` / HWC debug logging from the remote source tree
3. port or re-run the China-app install path on Guest4K
4. continue Douyin debugging from a real booting `4K` Android base instead of the old mixed baselines
