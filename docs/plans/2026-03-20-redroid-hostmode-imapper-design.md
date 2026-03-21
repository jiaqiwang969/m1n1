# Redroid Host-Mode IMapper Gate Design

## Goal

Repair the Mesa `u_gralloc` Android Soong build so host-mode can actually attempt the IMapper backend instead of dropping straight to fallback gralloc.

## Problem Statement

The current host-mode failure on `wjq@192.168.1.107` shows this chain:

- `ro.boot.redroid_gpu_mode=host`
- `ro.hardware.egl=mesa`
- Mesa logs `Using fallback gralloc implementation`
- then EGL logs:
  - `failed to get driver name for fd -1`
  - `egl: failed to create dri2 screen`
  - `Failed to open any DRM device`
- then `surfaceflinger` aborts because no usable EGL config exists

Source inspection on `dell@192.168.1.104` narrowed the failure further:

- `external/mesa3d/src/egl/drivers/dri2/platform_android.c` calls `u_gralloc_create(U_GRALLOC_TYPE_AUTO)`
- `external/mesa3d/src/util/u_gralloc/Android.bp` already compiles `u_gralloc_imapper5_api.cpp`
- but `external/mesa3d/src/util/u_gralloc/u_gralloc.c` only adds the IMapper backend to the AUTO candidate list when `USE_IMAPPER4_METADATA_API` is defined
- the current Soong build does not define that macro
- verification on the built archive showed:
  - `mesa_u_gralloc.a` contains `u_gralloc_imapper5_api.o`
  - `u_gralloc.o` references `u_gralloc_cros_api_create` and `u_gralloc_fallback_create`
  - `u_gralloc.o` does not reference `u_gralloc_imapper_api_create`

That means the IMapper implementation exists in the archive but is dead code for AUTO selection.

## Chosen Approach

Apply the smallest Android Soong fix first:

- keep `u_gralloc_imapper5_api.cpp`
- add the legacy gate macro `USE_IMAPPER4_METADATA_API` in `external/mesa3d/src/util/u_gralloc/Android.bp`
- rebuild only `mesa_u_gralloc`
- verify that the rebuilt `u_gralloc.o` now references `u_gralloc_imapper_api_create`

This is intentionally narrow. It proves whether the current root cause hypothesis is correct before we spend time rebuilding and deploying larger Mesa shared libraries.

## Rejected Alternatives

### Rewrite the C gate to a new macro name

Possible, but larger than necessary for the first proof step. Mesa's own `meson.build` still uses the legacy macro name even for the IMapper5 file, so matching that behavior is the safest minimal change.

### Rebuild and deploy all Mesa libraries immediately

Too large for the current evidence quality. First prove the backend is actually enabled in the static archive used by Android builds.

### Change runtime DRM/EGL behavior first

Not justified yet. The current failure happens before the IMapper path is even eligible in AUTO mode.

## Verification Target

The first experiment is successful if all of the following become true on `104`:

- `mesa_u_gralloc.a` still contains `u_gralloc_imapper5_api.o`
- `u_gralloc.o` now references `u_gralloc_imapper_api_create`
- the archive rebuild finishes cleanly

Only after that proof should we rebuild or deploy any runtime shared libraries.
