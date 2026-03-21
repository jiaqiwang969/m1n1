# Minigbm Lock Upgrade Design

**Context**

Douyin crashes in `libttmplayer.so` on Android 16 with `SIGSEGV` / `SEGV_ACCERR` while touching a
`/dev/dri/renderD128` mapping. The latest correlation capture shows the crashing address
`0xe96821670000` was first mapped by `minigbm` with `map_flags=0x1` and later reused for a
`map_flags=0x3` lock without recreating or upgrading the mapping.

**Root Cause**

[`cros_gralloc_buffer::lock()`](/Users/jqwang/25-红手指手机/redroid16-src/external/minigbm/cros_gralloc/cros_gralloc_buffer.cc)
reuses `lock_data_[0]->vma->addr` whenever a cached mapping exists. It does not check whether the
new lock asks for stronger permissions than the cached mapping. In the failing trace, a read-only
mapping is reused by a later read-write lock, so the app writes into an `r--` render node mapping
and crashes.

**Recommended Fix**

Keep the cached mapping model, but upgrade permissions before reuse when the requested lock needs
write access and the cached VMA is only read-only.

1. Add a small helper that detects whether a cached mapping needs a protection upgrade.
2. Add a helper that computes the merged `map_flags` for the upgraded mapping.
3. In `cros_gralloc_buffer::lock()`, call `mprotect()` on the cached VMA before reuse when the new
   lock needs stronger permissions.
4. Update the cached `vma->map_flags` after a successful upgrade so later locks see the current
   state.

**Why This Design**

This is narrower than forcing all mappings to be read-write, and safer than unmapping/remapping a
buffer that may still have outstanding lock users. It preserves the existing caching behavior while
fixing the exact compatibility hole shown by the crash evidence.

**Test Strategy**

Add a small host unit test for the permission-upgrade decision helper, then build and run that test.
After that, rebuild `libminigbm_gralloc`, deploy the updated gralloc stack, and verify Douyin no
longer crashes at startup under the same baseline configuration.
