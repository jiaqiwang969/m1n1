# Guest4K Mainline: How This Stack Actually Works

This guide explains the current working mainline in operator terms.

It is not a generic Redroid guide.
It describes the exact shape that currently works in this workspace.

## 1. The Working Shape

The current mainline is:

- `16K` Asahi Linux host
- `4K` Ubuntu microVM guest
- Redroid running inside that `4K` guest
- Douyin running inside that guest

Why this shape matters:

- the host kernel page size stays `16K`
- the Android userspace that Douyin actually runs on is `4K`
- that avoids the worst `16K` compatibility problems without requiring a full host reinstall

In short:

- keep the host stable
- isolate Android compatibility inside the guest

## 2. Why Direct-Host Is Not The Mainline

The old direct-host path is no longer the default direction.

It remains useful only as:

- historical reference
- comparison material
- a place to borrow old helper logic when explicitly needed

The mainline is `Guest4K` because it is the path that simultaneously achieved:

- Android boot
- working display
- working input
- working Douyin install
- working Douyin launch
- host-audible playback

That is the real success condition.

## 3. Display Path

The host sees the guest through:

- guest Android VNC server on `127.0.0.1:5901`
- TigerVNC on the KDE desktop of `192.168.1.107`

The operator entrypoint is:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh viewer
```

Important detail:

- the default viewer is now TigerVNC
- the older Python viewer is explicit fallback only:

```bash
VIEWER_MODE=python zsh redroid/scripts/redroid_guest4k_107.sh viewer
```

Why this was changed:

- the Python viewer used `adb exec-out screencap` in a loop
- that added extra CPU pressure inside Android
- it made video smoothness analysis less trustworthy

The script now cleans up any leftover Python screencap viewer before launching TigerVNC.

## 4. Graphics Reality

The current display path is usable, but it is not yet the final graphics solution.

Current facts from the promoted srcbuild virgl mainline:

- `ro.hardware.gralloc=minigbm`
- `sys.boot_completed=1`
- `init.svc.surfaceflinger=running`
- filtered logcat repeatedly shows `Using gralloc0 CrOS API`

That means:

- the validated default is no longer the old software-only fallback line
- the stack is operational on the promoted source-consistent virgl path
- graphics still need performance characterization, but the mainline is no longer
  described by `ANGLE + SwiftShader`

So when video stutters today, the right mental model is:

- some of the pain was viewer overhead and host contention
- that overhead has been reduced
- the remaining work should be measured on the promoted virgl path first, not on
  the old fallback assumptions

Important separation:

- the stable mainline is now the promoted srcbuild virgl path
- the old `ANGLE + SwiftShader` line is preserved only as explicit legacy fallback
- a separate `mesa/virtio` boot-prop experiment surface still exists, but it is not the
  default operator path and it can still reproduce the old import-failure chain

So there are really two different problems:

- stable mainline: keep the promoted virgl path healthy and characterize its
  remaining performance bottlenecks
- experimental boot-prop line: still isolate and diagnose the narrower
  `eglCreateImageKHR` import failure when explicitly opting into that surface

The current best root-cause hypothesis for the experimental boot-prop line is now narrower:

- virgl itself is not the first unknown anymore
- the likely mismatch is that a renderable RGBA buffer is still going through the
  external-texture import path
- the next disciplined step is a minimal experiment around renderable-vs-external import
  semantics, not more broad host tuning

## 5. Audio Path

The current audio chain is:

- Douyin audio track
- Android `AudioFlinger`
- guest ALSA device
- QEMU virtual audio stream
- host PipeWire
- host speaker sink

This is the critical point:

- audio is not fake anymore
- it is a real exported stream from the microVM into the host desktop audio graph

Current operator action:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh audio-diagnose
```

That command checks three layers together:

- guest `/dev/snd` visibility
- Android playback state
- host PipeWire/QEMU stream state

## 6. The Audio Routing Fix That Matters

One real bug that was fixed:

- the host recovery logic used to force QEMU audio to the headphone sink
- on this machine that sink can exist while not being physically available
- result: the stream was alive, but no sound was heard

The mainline script now behaves differently:

- it follows the current host default sink by default
- it still restores mute/volume on the QEMU stream
- it still allows explicit override via `HOST_AUDIO_TARGET_SINK`

Operationally this means:

- default behavior is safer
- speaker playback survives more host state changes

## 7. Douyin State

What has been demonstrated on the mainline:

- Douyin installs
- Douyin starts
- Douyin can be interacted with
- real audio can be heard on the host

What is still not perfect:

- long-session smoothness
- rendering performance
- residual audio artifacts

The current audio artifact sounds more like:

- low-frequency distortion
- rumble-like instability

and less like:

- a full-spectrum decode failure
- total audio path collapse

That distinction matters because it changes the next debugging step.

## 8. What To Do Next If Audio Polish Resumes

Do not return to blind parameter twiddling first.

The next disciplined step should be:

1. capture a short host-side sample of the QEMU output
2. inspect it with FFT / spectrogram
3. decide whether the artifact is:
   - low-frequency rumble
   - resampling wobble
   - periodic buffer underrun
   - channel/filter artifact
4. only then choose:
   - low-cut filtering
   - resampling changes
   - PipeWire quantum changes
   - QEMU timer / period tuning

Without that evidence, further tuning quickly becomes guesswork.

## 9. Day-To-Day Operator Flow

Typical mainline flow:

```bash
export SUDO_PASS='...'

zsh redroid/scripts/redroid_guest4k_107.sh vm-start
zsh redroid/scripts/redroid_guest4k_107.sh restart-preserve-data
zsh redroid/scripts/redroid_guest4k_107.sh verify
zsh redroid/scripts/redroid_guest4k_107.sh viewer
zsh redroid/scripts/redroid_guest4k_107.sh douyin-start
```

Optional phone persona flow:

```bash
export SUDO_PASS='...'

zsh redroid/scripts/redroid_guest4k_107.sh phone-mode
zsh redroid/scripts/redroid_guest4k_107.sh verify
zsh redroid/scripts/redroid_guest4k_107.sh viewer
zsh redroid/scripts/redroid_guest4k_107.sh douyin-start
```

Important operator semantics:

- baseline `restart` and `restart-preserve-data` remain the default rollback-safe path
- `phone-mode` is optional and reversible
- `phone-mode` stays on the same `Guest4K` mainline container path, it does not revive the old direct-host branch

Stage 1 shaping scope is intentionally narrow:

- shape `ro.product.*`, `ro.product.system.*`, `ro.product.vendor.*`, and `ro.product.odm.*`
- set a phone-like `device_name`
- hide `/system/xbin/su`

Stage 1 does not try to hide the full boot/runtime substrate:

- `ro.build.fingerprint` is intentionally left unchanged
- `ro.build.type`, `ro.build.tags`, and `ro.debuggable` are intentionally left unchanged
- boot-critical `redroid` / `qemu=1` traits are intentionally left unchanged
- no telephony, TEE, Play Integrity, or hardware attestation spoofing is attempted here

If the promoted mainline needs to be backed out quickly:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh restart-legacy
zsh redroid/scripts/redroid_guest4k_107.sh verify
```

If sound is missing:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh audio-diagnose
zsh redroid/scripts/redroid_guest4k_107.sh verify
```

## 10. What Must Be Preserved

When changing this stack, preserve these properties unless there is a very strong reason not to:

- `16K` host, `4K` guest
- Redroid inside guest, not directly on host
- TigerVNC as default viewer
- host PipeWire as real audio sink
- srcbuild virgl as the default restart surface
- baseline `restart` as the default rollback-safe surface
- `phone-mode` only as an optional app-facing shaping layer
- the old `ANGLE + SwiftShader` line only as explicit legacy fallback
- main operator entrypoint:
  `redroid/scripts/redroid_guest4k_107.sh`

If a change does not improve this path directly, it probably does not belong on the critical path.
