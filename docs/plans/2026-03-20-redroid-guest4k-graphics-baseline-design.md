# Redroid Guest4K Graphics Baseline Design

## Context

The repository already has a proven Guest4K runtime path:

- host: `192.168.1.107`
- host kernel page size: `16384`
- guest page size: `4096`
- host-visible guest SSH: `127.0.0.1:2222`
- host-visible guest ADB: `127.0.0.1:5556`
- host-visible guest VNC: `127.0.0.1:5901`
- operator: `redroid/scripts/redroid_guest4k_107.sh`

Fresh verification on `2026-03-20` still confirms that this path boots:

- `zsh redroid/scripts/redroid_guest4k_107.sh verify`
- guest SSH succeeds
- guest `getconf PAGE_SIZE=4096`
- `adb connect 127.0.0.1:5556` shows `device`
- `sys.boot_completed=1`
- `init.svc.vendor.vncserver=running`
- VNC returns `RFB 003.008`

Fresh package-state checks on the same day also confirm that Douyin is now past the old page-size gate on Guest4K:

- `pm path com.ss.android.ugc.aweme` returns the installed APK path
- `dumpsys package com.ss.android.ugc.aweme` shows `pageSizeCompat=0`

That means the first blocker on Guest4K is no longer package-manager page-size compat.

The current failure is lower in the graphics baseline. A fresh cold-start repro on `2026-03-20` still shows:

- `am start -W -n com.ss.android.ugc.aweme/.main.MainActivity` completes
- 10 seconds later there is no live Douyin PID
- focused app returns to `com.android.launcher3/.uioverrides.QuickstepLauncher`
- logcat shows repeated:
  - `DRM_IOCTL_MODE_CREATE_DUMB failed (4, 13)`
  - `android.hardware.graphics.allocator-service.minigbm: Failed to create bo.`
  - `drawRenderNode called on a context with no surface!`

The important system-level conclusion is:

- Guest4K solved the page-size layer
- Guest4K did not yet solve the graphics/allocator baseline

## Root-Cause Boundary

The currently maintained Guest4K script still starts Redroid with:

- `--privileged`
- `-v /dev/dri:/dev/dri`
- no explicit DRI masking

That shape is convenient, but it also means every guest DRI node is exposed into the container. The earlier direct-host investigation already proved why this matters:

- `--privileged` auto-exposes extra DRI nodes
- if the wrong DRI node becomes visible to minigbm, dumb-buffer allocation fails before app-specific debugging even starts

Fresh guest inspection shows the current guest host has both:

- a virtio-backed DRM device
- a `vkms` DRM device after `modprobe vkms`

So Guest4K is now in the same class of problem that direct-host 16K hit earlier:

- graphics node exposure must be explicit
- otherwise allocator behavior is ambiguous and regressions are easy to misread as "Douyin still broken"

## Goals

- Separate the Guest4K graphics-baseline problem from Douyin-specific runtime work.
- Preserve the current bootable Guest4K path as the default baseline.
- Add an explicit, script-level experiment surface for graphics profiles so live tests become repeatable.
- Keep the first change narrow enough that it does not replace the canonical `restart` behavior by accident.

## Non-Goals

- Do not claim a graphics fix yet.
- Do not switch the default Guest4K restart path away from the currently bootable shape.
- Do not re-open direct-host `restart-4k`.
- Do not bundle allocator source patches, driver changes, and operator refactors into one step.

## Options Considered

### Option 1: Keep graphics experiments manual

Pros:

- no code changes
- zero risk to current script behavior

Cons:

- experiments remain hard to replay exactly
- the `--privileged` DRI auto-exposure trap stays implicit
- operator history continues to drift into shell scrollback instead of the repo

### Option 2: Add an explicit Guest4K graphics-profile surface

Pros:

- smallest useful step
- preserves the current bootable default
- makes DRI exposure choices explicit in dry-run output and tests
- lets future live experiments compare canonical vs experimental profiles cleanly

Cons:

- does not solve graphics on its own
- adds script branching that needs tests

### Option 3: Replace the default Guest4K baseline with a `vkms`-only profile now

Pros:

- aggressively pushes toward the known-good direct-host pattern

Cons:

- too risky
- current live experiments already showed allocator init failure and `surfaceflinger` restart loops on naive Guest4K `vkms` mapping
- would blur the line between "current bootable baseline" and "experimental repair path"

Recommended: Option 2.

## Approved Design

### Operator shape

Keep `redroid/scripts/redroid_guest4k_107.sh restart` boot-compatible by default, but make its graphics choice explicit through environment-backed profile selection.

Initial profiles:

- `guest-all-dri`
  - default
  - matches the current bootable script behavior
  - keeps `-v /dev/dri:/dev/dri`
- `guest-vkms`
  - experimental
  - prepares `vkms` in the guest
  - mounts only a chosen guest DRM card into container `/dev/dri/renderD128`
  - masks the other guest DRI nodes that would otherwise leak in through `--privileged`

The profile name should be visible in script logs and dry-run output.

### Minimal configurability

Do not build a full generic device-mapping framework yet.

Instead, add only the minimum knobs needed for controlled repros:

- `GRAPHICS_PROFILE`
- `VKMS_CARD_NODE`

`VKMS_CARD_NODE` should default to the guest node seen in the current live baseline, but remain overrideable because guest card numbering can drift.

### Safety boundary

Do not make `guest-vkms` the default. The first safe step is to expose the operator surface and keep the known-booting path intact.

That gives the next live round a clean A/B shape:

- canonical bootable path: `GRAPHICS_PROFILE=guest-all-dri`
- controlled experimental path: `GRAPHICS_PROFILE=guest-vkms`

### Test strategy

Add dry-run regression coverage first. The tests should prove:

- default restart still shows the current `/dev/dri:/dev/dri` mount
- experimental restart shows `vkms` preparation and explicit masked/remapped DRI mounts
- dry-run output exposes the chosen graphics profile
- `--network host` still does not appear

Live verification for the first code step should focus on two questions only:

1. Does the default profile still boot exactly as before?
2. Can the experimental profile now be launched reproducibly without ad-hoc shell editing?

## Next Step

Write the implementation plan for the graphics-profile surface, then add the first failing dry-run test before touching the script.
