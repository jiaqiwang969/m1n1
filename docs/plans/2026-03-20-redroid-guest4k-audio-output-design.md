# Redroid Guest4K Audio Output Design

## Context

The repository already has a working Guest4K mainline:

- host: `wjq@192.168.1.107`
- host OS: Asahi Linux on Apple Silicon
- host kernel page size: `16384`
- guest: Ubuntu microVM at `/home/wjq/vm4k/ubuntu24k`
- guest kernel page size: `4096`
- Redroid runs inside the guest
- host-visible guest ADB: `127.0.0.1:5556`
- host-visible guest VNC: `127.0.0.1:5901`

Fresh runtime work already proved that the visible display problem was not TigerVNC itself. The actual issue was the guest display mode exposed by QEMU. After setting:

- `-device virtio-gpu-pci,xres=800,yres=1280`

the full portrait phone frame became stable again across:

- `adb shell wm size`
- `dumpsys window displays`
- `adb screencap`
- `FrameOutput: copyFrame`
- host VNC viewer output

Douyin is also back to the point where it launches on Guest4K, so the next missing system capability is audio.

The user requirement is explicit:

- sound should come out on the Asahi Linux host `192.168.1.107`
- this should be a root fix, not an application-layer workaround
- TigerVNC is acceptable for display, but not as the audio transport

## Current Evidence

The host audio stack is alive on `107`:

- `pipewire.service` is running
- `pipewire-pulse.service` is running
- `wireplumber.service` is running
- `pactl info` succeeds over SSH

The current QEMU build on `107` supports these audio backends:

- `alsa`
- `jack`
- `oss`
- `pa`
- `pipewire`
- `sdl`
- `spice`
- `wav`

The same QEMU build exposes these relevant emulated sound devices:

- `intel-hda`
- `hda-output`
- `hda-duplex`
- `AC97`
- `ES1370`

It does not expose a `virtio-snd-pci` device in `qemu-system-aarch64 -device help`.

Inside the Android guest today:

- `/dev/snd` did not yet show playable PCM devices before adding a VM sound card
- `audioserver` is running
- `vendor.audio-hal` is running
- audio policy still describes a generic `Speaker`
- the active audio service is `/vendor/bin/hw/android.hardware.audio.service`

That means Android-side audio userspace exists, but there is no end-to-end proof yet that a real virtual sound device reaches the guest kernel.

## Problem Statement

Right now Guest4K has a complete graphics path but no proven audio hardware path.

Without a virtual sound device at the VM boundary:

- the Linux guest cannot expose a real ALSA playback device
- Android cannot route media output to a concrete PCM sink
- any app-level testing is ambiguous because the lower hardware layer is missing

So the first missing layer is not Douyin, not VNC, and not Android UI. It is the VM audio device boundary.

## Goals

- Make Guest4K expose a real virtual playback device to the Linux guest.
- Route that audio to PipeWire on the Asahi host.
- Keep the display fix intact:
  - `virtio-gpu-pci,xres=800,yres=1280`
- Verify the hardware path from host QEMU to guest ALSA before changing Android HAL code.
- Keep the first step small and reversible.

## Non-Goals

- Do not treat TigerVNC as an audio solution.
- Do not jump directly into Android HAL source changes before guest ALSA enumeration exists.
- Do not rebuild the whole Android image in the first step.
- Do not change the current Guest4K display baseline while introducing audio.

## Options Considered

### Option 1: Export audio through the remote viewer layer

Examples:

- TigerVNC audio forwarding
- screen/audio mirroring tools as the primary design

Pros:

- less VM-level work

Cons:

- wrong abstraction layer
- TigerVNC does not provide the needed audio transport here
- does not prove Guest4K has a real device-level audio path
- still leaves Android running on a machine with no actual sound hardware

### Option 2: Add a QEMU virtual sound card and send it to PipeWire on the host

Shape:

- QEMU `-audiodev pipewire`
- QEMU `-device intel-hda`
- QEMU `-device hda-output`

Pros:

- fixes the missing layer at the VM boundary
- makes the guest look more like a real device with real playback hardware
- aligns with the host audio stack that is already running
- keeps all audio local to `107`, which matches the user goal

Cons:

- may still require guest kernel or Android HAL follow-up
- requires careful verification after VM restart

### Option 3: Skip QEMU audio and patch Android to synthesize or redirect sound elsewhere

Pros:

- theoretically possible

Cons:

- wrong order
- much harder to reason about
- hides whether the VM itself can expose standard audio hardware
- would make later debugging more fragile

Recommended: Option 2.

## Approved Design

### Architecture

The root-fix audio path should be:

`Android app -> Android audio HAL/service -> guest ALSA device -> QEMU emulated HDA device -> host PipeWire sink`

This keeps the fix at the lowest missing layer that is still practical to change quickly.

### QEMU device choice

Use:

- `-audiodev pipewire,id=audio0`
- `-device intel-hda`
- `-device hda-output,audiodev=audio0`

Reason:

- `pipewire` is already available and running on the host
- `virtio-snd` is not available in the current QEMU build
- `intel-hda` is the cleanest available PCI audio device currently exposed by this host QEMU

### Change boundary

The first implementation change belongs in:

- `/home/wjq/vm4k/ubuntu24k/launch.sh`

and should only do two things:

- preserve the proven portrait GPU mode
- add the minimal QEMU audio backend and sound device

No Android build changes belong in this first pass.

### Verification boundary

After the VM restarts, verify in this order:

1. Host QEMU process starts cleanly with the new audio arguments.
2. Host PipeWire sees a new client or sink input from QEMU.
3. Guest Linux sees an audio PCI device and ALSA nodes.
4. Guest Linux exposes:
   - `/dev/snd/pcm*`
   - `/proc/asound/cards`
   - `aplay -l`
5. Only if all of that is true, move upward into Android audio routing checks.

### Failure branches

If QEMU starts but guest Linux still has no playable ALSA device:

- inspect guest kernel driver support first
- inspect `dmesg` for `snd_hda_*` or generic PCI audio messages

If guest ALSA appears but Android stays silent:

- inspect Android HAL and policy binding next
- confirm what `/vendor/bin/hw/android.hardware.audio.service` actually opens

If QEMU audio never appears on the host:

- inspect PipeWire backend arguments and host session environment before touching the guest

## Success Criteria

The first pass is successful if all of the following are true:

- Guest4K still boots normally.
- The display remains `800x1280`.
- The guest Linux kernel enumerates a sound device.
- `aplay -l` shows at least one playback device.
- the host PipeWire stack shows QEMU attached as an audio client or sink input

App-level audible playback is ideal, but not required for the first pass. The first pass is about proving the hardware boundary.

## Next Step

Write the implementation plan, then patch the microVM launch script on `107`, restart the VM, and verify guest ALSA enumeration before any Android HAL changes.
