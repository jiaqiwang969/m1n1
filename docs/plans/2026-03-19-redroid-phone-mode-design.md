# Redroid Phone-Mode Runtime Shaping Design

## Context

The current Redroid baseline on `192.168.1.107` already reaches a partial Douyin runtime path:

- container boot is stable
- VNC input works
- launcher apps no longer bounce back
- Douyin can pass the Android 16 page-size gate and render its privacy guide / home UI before a later native crash

The next risk is not only process startup. It is also environment exposure. The current app-facing surface still shows obvious non-phone traits such as:

- `ro.product.*=redroid*`
- `ro.build.type=userdebug`
- `ro.build.tags=test-keys`
- `ro.build.fingerprint=redroid/...`
- `settings get global device_name = redroid16_arm64_only`
- `/system/xbin/su` exists

At the same time, some Redroid traits are likely boot-critical:

- `androidboot.hardware=redroid`
- `ro.boot.hardware=redroid`
- `ro.hardware=redroid`
- `qemu=1` in the init command line

Those should not be touched in the first shaping pass because they may break boot or graphics bring-up.

## Goal

Add an explicit operator workflow that restarts Redroid in a more phone-like runtime mode for Chinese commercial apps, while preserving the existing root-safe maintenance baseline as the default recovery path.

## Options Considered

### Option 1: Only spoof user-visible product properties

Pros:

- lowest implementation risk
- easy to roll back
- does not disturb the current operator workflow much

Cons:

- `/system/xbin/su` still exists
- many root checks will still fire

### Option 2: Spoof safe product properties, hide `su`, and keep ADB usable

Pros:

- removes the most obvious app-facing Redroid traits without touching boot-critical hardware identity
- keeps the stable maintenance path intact
- can be implemented as an explicit runtime mode instead of mutating the base image permanently

Cons:

- still leaves deeper container signals such as `ro.boot.hardware=redroid` and init `qemu=1`
- requires extra operator plumbing and verification

### Option 3: Deep hiding with Magisk/Shamiko-style behavior

Pros:

- broadest possible hiding surface

Cons:

- much higher complexity
- risks destabilizing the now-working Redroid baseline
- poor fit for the current "keep it reproducible" goal

Recommended: Option 2.

## Approved Design

### Script surface

Extend `redroid/scripts/redroid_root_safe_107.sh` with a new explicit action:

- `phone-mode`

This action will:

1. prepare a runtime phone profile on the remote host
2. restart the existing container with extra bind mounts for the shaped files
3. wait for boot and VNC readiness
4. set a more phone-like global `device_name`
5. print the resulting property and `su` visibility state

Normal `restart` remains the maintenance/root-safe baseline. It is also the rollback path.

### Runtime shaping scope

The implemented shaping pass only changes app-facing product properties that are safe to override through mounted property files:

- `ro.product.brand`
- `ro.product.manufacturer`
- `ro.product.model`
- `ro.product.device`
- `ro.product.name`
- `ro.product.system.*`
- `ro.product.vendor.*`
- `ro.product.odm.*`

It will also:

- `settings put global device_name ...`
- hide `/system/xbin/su`
- mount trusted `/product/etc/security/adb_keys`

The implemented pass explicitly does not change:

- `androidboot.hardware`
- `ro.boot.hardware`
- `ro.hardware`
- init command-line `qemu=1`
- `ro.build.*`
- `ro.debuggable`

### File strategy

Do not permanently rewrite the imported Redroid image.

Instead, the operator script should generate a remote runtime profile directory by:

1. copying the current image's `/system/build.prop`
2. copying the current image's `/vendor/build.prop`
3. applying a small set of replacements and appended overrides
4. creating a replacement `/system/xbin` directory that omits `su`
5. copying the host's trusted `adbkey.pub` into a staged `adb_keys` file

Then `podman run` mounts:

- shaped `system.build.prop` over `/system/build.prop`
- shaped `vendor.build.prop` over `/vendor/build.prop`
- replacement `system_xbin/` over `/system/xbin`
- staged `adb_keys` over `/product/etc/security/adb_keys`

This keeps the base image untouched and makes rollback trivial.

### Profile identity

The initial profile remains a synthetic but internally consistent China-phone persona:

- brand/manufacturer: `Xiaomi`
- marketing name: `Xiaomi 13`
- model: `23127PN0CC`
- device/name: `fuxi`

The important property is not perfect real-device impersonation. The important property is removing the current `redroid/.../su` cluster from the first-layer app checks while keeping the maintenance path stable. A broader spoofing pass that changed `ro.build.*` and `ro.debuggable` was tried and then abandoned because it destabilized ADB and app startup.

### Verification behavior

`verify` should remain the main generic health check, but it should also report:

- whether the current container is in baseline mode or phone mode
- key product/build properties
- whether `/system/xbin/su` is visible
- current global `device_name`
- current Douyin `pageSizeCompat` state if Douyin is installed

### Safety and rollback

- `restart` must continue to work exactly as the known-good baseline.
- `phone-mode` must not mutate the base image or the persistent data volume.
- If phone-mode fails to boot, the operator falls back to plain `restart`.
- The design accepts that deeper detection may still remain after this pass.

### Testing

Add dry-run coverage that proves:

- usage text includes `phone-mode`
- `--dry-run phone-mode` shows profile preparation, shaped bind mounts, and device-name update
- `--dry-run verify` surfaces the new phone-mode verification lines

## Next Step

If Douyin still fails after this pass, the next investigation should measure:

- whether the remaining blocker is the current `libtnet-3.1.14.so` `JNI_OnLoad` crash on `UPush-1`
- whether `ro.boot.hardware/qemu` exposure or missing kernel / Android devices still matter after the `libtnet` blocker is understood
- whether stronger hiding is worth the stability cost
