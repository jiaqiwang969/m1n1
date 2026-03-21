# Redroid Guest4K Audio Output Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a real virtual audio path to Guest4K so the 4 KB guest can expose a playback device and route sound into PipeWire on the Asahi Linux host.

**Architecture:** Keep the already-fixed portrait display baseline unchanged, then add the smallest possible QEMU audio layer: a PipeWire backend plus an emulated HDA output device. Verify the stack bottom-up: host PipeWire, guest Linux PCI/ALSA enumeration, then Android routing only if the lower layers exist.

**Tech Stack:** `zsh`, `ssh`, `qemu-system-aarch64`, `PipeWire`, `ALSA`, `adb`, `podman`, Markdown

---

### Task 1: Re-anchor the current Guest4K baseline

**Files:**
- Validate: `README.md`
- Validate: `redroid/scripts/redroid_guest4k_107.sh`
- Validate: `docs/plans/2026-03-20-redroid-guest4k-audio-output-design.md`

**Step 1: Re-verify the current display baseline**

Run:

```bash
sshpass -p '123123' ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  "sed -n '1,220p' /home/wjq/vm4k/ubuntu24k/launch.sh | grep -n 'virtio-gpu-pci'"
```

Expected:

- the launch script still contains `virtio-gpu-pci,xres=800,yres=1280`

**Step 2: Re-verify Guest4K service baseline**

Run:

```bash
export SUDO_PASS=123123
zsh redroid/scripts/redroid_guest4k_107.sh verify
```

Expected:

- guest SSH succeeds
- ADB on `127.0.0.1:5556` is `device`
- VNC on `127.0.0.1:5901` returns an `RFB` banner

### Task 2: Confirm host audio prerequisites

**Files:**
- Modify: none

**Step 1: Verify PipeWire stack on `107`**

Run:

```bash
sshpass -p '123123' ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  'systemctl --user --no-pager --plain --type=service | grep -E "pipewire|wireplumber|pulseaudio" || true; pactl info | sed -n "1,40p"'
```

Expected:

- `pipewire.service` is running
- `pipewire-pulse.service` is running
- `wireplumber.service` is running
- `pactl info` succeeds

**Step 2: Reconfirm QEMU audio capabilities**

Run:

```bash
sshpass -p '123123' ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  'qemu-system-aarch64 -audiodev help; echo "---"; qemu-system-aarch64 -device help | grep -iE "virtio.*snd|hda|ac97|es1370|intel-hda"'
```

Expected:

- `pipewire` appears in `-audiodev help`
- `intel-hda` and `hda-output` appear in device help
- `virtio-snd-pci` does not appear

### Task 3: Patch the microVM launch script with the smallest audio change

**Files:**
- Modify: remote `wjq@192.168.1.107:/home/wjq/vm4k/ubuntu24k/launch.sh`

**Step 1: Back up the current launch script**

Run:

```bash
sshpass -p '123123' ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  'cp /home/wjq/vm4k/ubuntu24k/launch.sh /home/wjq/vm4k/ubuntu24k/launch.sh.bak-audio-$(date +%Y%m%d-%H%M%S)'
```

Expected:

- backup file exists beside `launch.sh`

**Step 2: Add the QEMU audio backend and device**

Modify the remote script so the QEMU command contains:

```bash
-audiodev pipewire,id=audio0
-device intel-hda
-device hda-output,audiodev=audio0
```

Keep:

```bash
-device virtio-gpu-pci,xres=800,yres=1280
```

Expected:

- no unrelated QEMU arguments are changed

**Step 3: Re-read the final script**

Run:

```bash
sshpass -p '123123' ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  'sed -n "1,240p" /home/wjq/vm4k/ubuntu24k/launch.sh'
```

Expected:

- the three new audio lines are present
- the portrait GPU line is still present

### Task 4: Restart the microVM and Guest4K runtime

**Files:**
- Validate: `redroid/scripts/redroid_guest4k_107.sh`

**Step 1: Restart the VM**

Run:

```bash
export SUDO_PASS=123123
zsh redroid/scripts/redroid_guest4k_107.sh vm-stop || true
zsh redroid/scripts/redroid_guest4k_107.sh vm-start
```

Expected:

- the VM starts without immediate QEMU argument errors

**Step 2: Restart the Guest4K Redroid container**

Run:

```bash
export SUDO_PASS=123123
IMAGE=localhost/redroid4k-root:minigbm-dropmaster-vncrotate \
  zsh redroid/scripts/redroid_guest4k_107.sh restart
```

Expected:

- Redroid restarts successfully
- ADB reconnects on `127.0.0.1:5556`
- VNC reconnects on `127.0.0.1:5901`

### Task 5: Verify the guest Linux audio hardware boundary

**Files:**
- Modify: none

**Step 1: Check PCI and kernel logs inside the guest**

Run:

```bash
sshpass -p '123123' ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /home/wjq/vm4k/ubuntu24k/guest_key -p 2222 wjq@127.0.0.1 \
   'lspci -nn | grep -i audio || true; echo ---; dmesg | grep -iE \"snd|hda|audio\" | tail -80 || true; echo ---; ls -l /dev/snd || true; echo ---; cat /proc/asound/cards || true; echo ---; aplay -l || true'"
```

Expected:

- PCI shows an audio device
- `/dev/snd` includes PCM-related nodes, not just `timer`
- `/proc/asound/cards` is not empty
- `aplay -l` shows at least one playback device

**Step 2: Check host PipeWire visibility**

Run:

```bash
sshpass -p '123123' ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  'pactl list short clients; echo ---; pactl list short sink-inputs'
```

Expected:

- QEMU or a new audio client is visible after VM boot

### Task 6: Branch on the evidence

**Files:**
- Validate: `docs/plans/2026-03-20-redroid-guest4k-audio-output-design.md`

**Step 1: If guest ALSA enumeration succeeds**

Run next:

```bash
adb -s 127.0.0.1:5556 shell dumpsys media.audio_flinger
adb -s 127.0.0.1:5556 shell dumpsys media.audio_policy
```

Expected:

- move to Android routing and playback verification

**Step 2: If guest ALSA enumeration fails**

Inspect next:

- guest kernel config for HDA and ALSA support
- loaded modules
- `dmesg` driver bind failures

Expected:

- no Android HAL source changes yet

### Task 7: Record and stabilize

**Files:**
- Modify: `README.md`
- Modify: `docs/guides/install-china-apps.md`

**Step 1: If the hardware layer is proven, document the new audio boundary**

Update repo docs to state:

- Guest4K display uses portrait `virtio-gpu`
- Guest4K audio uses QEMU HDA into PipeWire

**Step 2: If the hardware layer is not yet proven, document the exact failure boundary**

Update repo docs to state:

- display is fixed
- audio experiment reached either:
  - no guest ALSA device
  - or guest ALSA present but Android still silent

Expected:

- the repo records the current root-cause boundary instead of relying on shell history
