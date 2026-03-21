# Redroid Guest4K ALSA HAL Design

## Context

Guest4K now has a stable graphics and input baseline:

- host: `wjq@192.168.1.107`
- host shape: `16K` Asahi Linux
- guest shape: `4K` Ubuntu microVM
- Android runtime: Redroid inside the guest
- guest ADB: `127.0.0.1:5556`
- guest VNC: `127.0.0.1:5901`

Audio hardware at the VM boundary is also already present:

- QEMU uses `-audiodev pipewire,id=audio0`
- QEMU exposes `intel-hda` plus `hda-output`
- guest Linux enumerates `HDA Intel`
- guest ALSA exposes `pcmC0D0p`
- direct guest-root `speaker-test` reaches host speakers

That means:

- `QEMU HDA -> guest ALSA -> host PipeWire` is proven
- TigerVNC is not the right layer to fix audio
- the remaining fault is above guest ALSA and below Android app playback

## Root Cause Boundary

Fresh runtime evidence narrowed the failure:

- Douyin playback is live
- `dumpsys audio` shows the player in `state:started`
- the active player is routed to `deviceIds:[2]`
- host PipeWire still shows the QEMU audio stream as `idle` / `corked`
- no Android-owned process actually opens `/dev/snd/pcmC0D0p`
- `android.hardware.audio.service` still loads:
  - `/vendor/lib64/hw/audio.primary.redroid.so`
  - `/vendor/lib64/hw/audio.r_submix.default.so`

This is the important conclusion:

- Android policy now believes it has an output device
- but the loaded primary HAL is not the correct implementation for the current Guest4K hardware path

## Why `audio.primary.redroid.so` Is Not The Final Path

The current `audio.primary.redroid.so` behaves like the older Redroid socket/proxy design, not like a
local ALSA primary HAL.

Evidence already collected:

- the binary contains socket-oriented strings such as:
  - `socket`
  - `listen on socket`
  - `bind socket`
  - `socket accept`
- Android init attempts to start supporting pieces that are absent in the Guest4K image:
  - `audio_proxy_service`
  - `vendor.audio-hal-aidl`

So continuing to tune this HAL would keep chasing the wrong architecture.

## Design Goal

Replace the Guest4K primary audio implementation with a real ALSA/tinyalsa HAL that can open the guest
PCM device directly.

The target path becomes:

`Douyin -> AudioTrack / AudioFlinger -> primary audio HAL -> tinyalsa / pcm_open -> guest HDA -> QEMU PipeWire -> host speakers`

## Options Considered

### Option 1: Keep patching `audio.primary.redroid.so`

Pros:

- smaller short-term code delta

Cons:

- wrong architectural layer
- still depends on missing proxy-side services
- does not explain why guest-root ALSA works while Android HAL playback does not

### Option 2: Switch Guest4K to the AOSP `goldfish/ranchu` tinyalsa HAL

Pros:

- already present in the source tree
- emulator-oriented rather than phone-SOC-specific
- uses `libtinyalsav2`
- actually opens PCM devices
- closer to the current Guest4K hardware shape

Cons:

- requires product packaging and policy wiring changes
- may require manifest or service-shape adjustments if current Redroid packaging diverged too far

### Option 3: Write a new Redroid-specific ALSA HAL from scratch

Pros:

- maximal long-term control

Cons:

- too large a first step
- duplicates behavior that likely already exists in AOSP
- slower path to first audible proof

Recommended: Option 2.

## Approved Design

### HAL Choice

Use the existing AOSP `goldfish/ranchu` audio HAL in:

- `device/generic/goldfish/hals/audio`

This is the current best candidate because it is:

- emulator-oriented
- tinyalsa-based
- already integrated with Android audio service modules and policy files

### Change Boundary

The first implementation pass should stay narrow:

- package the `goldfish/ranchu` audio implementation into the Redroid product
- package the matching audio policy XMLs
- keep the proven Guest4K graphics and VM launch configuration unchanged

The first pass should not:

- redesign QEMU audio
- change TigerVNC
- change the app layer
- write a brand new HAL

### Verification Boundary

The new HAL trial is only considered successful if all of the following become true at runtime:

1. `android.hardware.audio.service` maps the new ALSA/tinyalsa implementation instead of
   `audio.primary.redroid.so`
2. guest Android-owned processes actually open `/dev/snd/pcmC0D0p`
3. host PipeWire shows `qemu-system-aarch64` as `running`, not `idle` / `corked`
4. during Douyin playback, the host speakers play the app audio

## Failure Branches

If the new HAL is packaged but `android.hardware.audio.service` still loads the old Redroid HAL:

- inspect product package precedence
- inspect VINTF / audio service selection
- inspect installed `/vendor/lib64/hw` contents in the built image

If the new HAL loads but still does not open PCM:

- inspect audio policy device mapping
- inspect logs from AudioFlinger and the new HAL
- compare against direct guest ALSA device names and supported formats

If the new HAL opens PCM but host audio stays idle:

- inspect QEMU stream state during active playback
- inspect guest sample format and channel configuration

## Success Criteria

The first solid success is not "a sound happened once". The success bar is:

- reproducible Douyin playback
- reproducible QEMU PipeWire activity during playback
- reproducible app audio through host speakers
- all of it running on the Guest4K mainline

That gives the project a real root fix instead of another temporary side path.
