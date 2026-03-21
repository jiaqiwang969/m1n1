# m1n1 Workspace: Guest4K Redroid Mainline

This repository is still the upstream `m1n1` source tree, but in this workspace it is used as the
home for one specific local system project:

- `16K` Asahi Linux host
- `4K` Ubuntu microVM guest
- Redroid running inside the `4K` guest
- Douyin installed and usable inside that guest

This path is the only project mainline.

Everything else, especially the older direct-host Redroid path, is now treated as:

- historical material
- frozen experiments
- not the default direction for future work

## Mainline Goal

The goal of this workspace is not "all possible Redroid shapes".

The goal is:

1. keep the `Guest4K` stack stable
2. keep Douyin usable inside it
3. improve interaction quality, audio quality, and day-to-day operability
4. document that path clearly enough that future work does not drift into dead ends

## Current Mainline

The verified runtime today is:

- host: `wjq@192.168.1.107`
- host OS: Asahi Linux
- host page size: `16384`
- microVM dir: `/home/wjq/vm4k/ubuntu24k`
- guest page size: `4096`
- operator script: `redroid/scripts/redroid_guest4k_107.sh`
- default image: `localhost/redroid4k-root:alsa-hal-ranchu-exp2`
- guest container: `redroid16kguestprobe`
- host-visible guest ADB: `127.0.0.1:5556`
- host-visible guest VNC: `127.0.0.1:5901`

This is the baseline that should be protected.

## What Already Works

The following has already been proven on the `Guest4K` mainline:

- the guest really runs with `PAGE_SIZE=4096`
- Android 16 boots to `sys.boot_completed=1`
- `surfaceflinger` and HWC stay up
- the guest graphics path is stable enough for real use
- the display baseline is portrait and phone-shaped
- VNC access works on the guest path
- Douyin is installed
- Douyin can be launched and interacted with
- guest audio is exported out to the host through PipeWire
- actual playback sound can be heard on the host side

In plain language: the mainline path is already usable.

## Current Mainline Problems

The remaining work is now optimization and hardening on the `Guest4K` path, not a rebuild from
scratch.

The current known problems are:

### 1. Audio still needs polishing

- sound is already routed correctly
- host recovery now follows the current PipeWire default sink instead of forcing a headphone-only path
- playback can still stutter or feel unstable during longer sessions
- the remaining artifact currently sounds more like low-frequency distortion or intermittent rumble than a full-band failure
- future audio work should start with captured samples plus FFT analysis instead of blind tuning

### 2. Viewer and interaction still need polishing

- TigerVNC is now the default viewer path
- the legacy Python `adb screencap` viewer is kept only as an explicit fallback via `VIEWER_MODE=python`
- VNC viewing works
- but window sizing, phone-frame feel, and interaction smoothness are still not ideal

### 3. Douyin runtime still needs day-to-day hardening

- the app is installed and usable
- but long-session smoothness, prompt handling, and recovery behavior still need cleanup

### 4. Operator workflow still needs cleanup

- the main script works
- but restart, verify, viewer, and recovery flows should be made more predictable and better
  documented

### 5. Documentation must stay aligned with the mainline

- future notes should describe the `Guest4K` path first
- old side tracks should not dominate the narrative

## Mainline Operator

Primary entry point:

- `redroid/scripts/redroid_guest4k_107.sh`

Supported actions:

- `vm-start`
- `vm-stop`
- `vm-status`
- `restart`
- `restart-preserve-data`
- `status`
- `verify`
- `viewer`
- `douyin-install`
- `douyin-start`
- `douyin-diagnose`
- `audio-diagnose`

Recommended daily flow:

```bash
export SUDO_PASS='...'

zsh redroid/scripts/redroid_guest4k_107.sh vm-start
zsh redroid/scripts/redroid_guest4k_107.sh restart
zsh redroid/scripts/redroid_guest4k_107.sh verify
zsh redroid/scripts/redroid_guest4k_107.sh viewer
```

If installed app state should be preserved:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh restart-preserve-data
```

Douyin flow:

```bash
LOCAL_DOUYIN_APK_PATH=/path/to/douyin.apk \
zsh redroid/scripts/redroid_guest4k_107.sh douyin-install

zsh redroid/scripts/redroid_guest4k_107.sh douyin-start
zsh redroid/scripts/redroid_guest4k_107.sh douyin-diagnose
zsh redroid/scripts/redroid_guest4k_107.sh audio-diagnose
```

If the APK is already staged on `192.168.1.107`, leave `LOCAL_DOUYIN_APK_PATH` unset and the
default remote path `/tmp/douyin.apk` will be used.

When audio playback feels unstable, use `audio-diagnose` first. It prints the current Android
playback surface, guest ALSA device visibility, and host PipeWire/QEMU node state in one pass.

Viewer defaults:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh viewer
```

This now launches TigerVNC on the remote KDE desktop and cleans up the old Python screencap
viewer if it is still running.

If you explicitly need the old helper for comparison:

```bash
VIEWER_MODE=python zsh redroid/scripts/redroid_guest4k_107.sh viewer
```

Host audio routing defaults:

- QEMU audio is recovered to the current host default sink
- `HOST_AUDIO_TARGET_SINK` can still override that behavior when needed
- `HOST_AUDIO_MOVE_TO_TARGET=0` disables sink moves and only restores mute/volume

## Mainline Technical Shape

The current `Guest4K` shape should be treated as intentional:

- full guest `/dev/dri` exposure inside the guest container
- `guest-all-dri` graphics profile
- isolated container networking with explicit published ports
- no default `--network host` inside the guest container
- real virtual audio device in the microVM
- host PipeWire as the audio sink

This shape won because it is the one that actually converged into a usable runtime.

Current rendering fact:

- the guest is still on `ANGLE + SwiftShader`, so graphics are functional but not yet on the final
  GPU-backed path

## Why This Is The Mainline

This path is the mainline because it solved the real product problem:

- Android boots
- graphics stays up
- Douyin installs
- Douyin runs
- sound comes out

That is the project center of gravity now.

Future work should improve this path instead of reopening lower-value architecture detours by
default.

## Frozen Historical Path

The old direct-host Redroid path still exists in the repository, but it is not the mainline.

Treat it as:

- archive
- reference material
- experimental branch only when explicitly requested

Do not treat it as the default fix direction.

Relevant older script:

- `redroid/scripts/redroid_root_safe_107.sh`

That script is kept for history and occasional comparison, not as the default operator path.

## Repository Layout

Upstream `m1n1` remains in its original layout:

- `src/`
- `proxyclient/`
- `rust/`
- `tools/`
- `Makefile`

The local Redroid workspace layer lives here:

- `redroid/scripts/`
- `redroid/profiles/`
- `redroid/tools/`
- `docs/guides/`
- `docs/plans/`
- `tests/redroid/`
- `tmp/`

## Working Rule For Future Changes

When deciding what to work on next, assume this priority order:

1. `Guest4K` runtime stability
2. Douyin usability on `Guest4K`
3. audio/video/interaction polish on `Guest4K`
4. operator and documentation cleanup for `Guest4K`

Anything outside that order should be treated as secondary unless explicitly requested.

## How It Works

For the current technical baseline and the operator-facing reasoning behind it, start here:

- `docs/guides/guest4k-mainline-how-it-works.md`

## Status Summary

Current status in one sentence:

`Guest4K` is already the working system; the remaining job is polish, hardening, and focused
iteration on that mainline.
