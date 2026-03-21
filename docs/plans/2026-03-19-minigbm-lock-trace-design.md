# Minigbm Lock Trace Design

**Goal:** Instrument the minigbm lock path so a single Douyin repro can show whether `cpuUsage`, `mapUsage`, `BO_MAP_WRITE`, and final `PROT_*` diverge before the `libttmplayer.so` write into `/dev/dri/renderD128`.

## Scope

The trace stays intentionally narrow. It covers only the path already implicated by the tombstones:

- `CrosGralloc4Mapper::lock`
- `convertToMapUsage`
- `cros_gralloc_driver::lock`
- `cros_gralloc_buffer::lock`
- `drv_get_prot`

It does not attempt broader graphics tracing, allocator redesign, or another blind library-swap experiment.

## Trace Shape

Use a single log marker string: `REDROID_LOCK_TRACE`.

Each trace line should capture only the fields needed to correlate one lock request across layers:

- `cpuUsage`
- derived `mapUsage`
- handle `usage`
- handle `format`
- dimensions
- `map_flags`
- whether `BO_MAP_WRITE` is present
- final `PROT_*`

## Log Gating

The trace is disabled by default and enabled only when a temporary debug property is set:

- property: `debug.redroid.minigbm_locktrace`

That keeps normal runtime noise unchanged and lets a single clean repro gather evidence with `adb shell setprop ... 1`.

## Verification Strategy

Use a tight red-green-debug loop:

1. Red: confirm current built artifacts do not contain `REDROID_LOCK_TRACE`.
2. Green: patch source, rebuild the affected minigbm artifacts, and confirm the marker string now exists in the built binaries.
3. Runtime: deploy only the rebuilt minigbm artifacts, enable the property, reproduce Douyin once, and grep logcat for `REDROID_LOCK_TRACE`.
4. Correlate the trace with the next tombstone or crash excerpt.

## Expected Outcome

This instrumentation should answer one concrete question:

Is the read-only `/dev/dri/renderD128` mapping caused by the mapper-side `cpuUsage` request already lacking write intent, or is write intent lost later inside the gralloc/minigbm lock chain?
