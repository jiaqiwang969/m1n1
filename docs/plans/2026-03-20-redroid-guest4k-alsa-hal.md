# Redroid Guest4K ALSA HAL Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current Guest4K primary audio path with an ALSA/tinyalsa HAL that can drive the guest HDA device and play Douyin audio through the Asahi host speakers.

**Architecture:** Keep the already-proven Guest4K VM audio boundary unchanged and swap only the Android primary audio implementation from the old Redroid socket/proxy HAL to the AOSP `goldfish/ranchu` tinyalsa path. Verify bottom-up: built image contents, runtime HAL mapping, guest PCM opens, then host PipeWire activity and audible playback.

**Tech Stack:** `ssh`, `sshpass`, `adb`, `podman`, Android product makefiles, Android audio policy XML, `qemu-system-aarch64`, `PipeWire`, `ALSA`, Markdown

---

### Task 1: Freeze the current failure boundary

**Files:**
- Validate: `docs/plans/2026-03-20-redroid-guest4k-alsa-hal-design.md`
- Validate: `docs/plans/2026-03-20-redroid-guest4k-root-cause.md`

**Step 1: Reconfirm the runtime symptom on `107`**

Run:

```bash
sshpass -p '123123' ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 '
adb -s 127.0.0.1:5556 shell dumpsys audio 2>/dev/null | \
  grep -n -E "AudioPlaybackConfiguration|state:started|deviceIds|u/pid:|usage=USAGE_MEDIA"
echo ---
pactl list sink-inputs 2>/dev/null | sed -n "/node.name = \"qemu-system-aarch64\"/,+20p"
'
```

Expected:

- Douyin player shows `state:started`
- the active media player shows `deviceIds:[2]`
- host QEMU stream still shows `Corked: yes` or otherwise stays idle

**Step 2: Reconfirm the currently loaded HAL**

Run:

```bash
sshpass -p '123123' ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  "ssh -i /home/wjq/vm4k/ubuntu24k/guest_key -o StrictHostKeyChecking=no -p 2222 wjq@127.0.0.1 \
   'echo 123123 | sudo -S sh -lc \"pid=\$(pidof android.hardware.audio.service); grep -E \\\"audio.primary|audio.r_submix\\\" /proc/\$pid/maps\"'"
```

Expected:

- runtime still maps `audio.primary.redroid.so`

### Task 2: Inspect the existing AOSP ALSA candidate on `104`

**Files:**
- Validate: remote `/home/dell/redroid-build/redroid16-src-cs/device/generic/goldfish/hals/audio/Android.bp`
- Validate: remote `/home/dell/redroid-build/redroid16-src-cs/device/generic/goldfish/hals/audio/policy/audio_policy_configuration.xml`
- Validate: remote `/home/dell/redroid-build/redroid16-src-cs/device/generic/goldfish/hals/audio/policy/primary_audio_policy_configuration.xml`

**Step 1: Confirm the module and policy names**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 '
cd /home/dell/redroid-build/redroid16-src-cs
sed -n "1,220p" device/generic/goldfish/hals/audio/Android.bp
echo ---
find device/generic/goldfish/hals/audio/policy -maxdepth 1 -type f | sort
'
```

Expected:

- the tree exports a `ranchu` audio HAL module
- matching policy XML files exist under `policy/`

**Step 2: Confirm the Redroid product does not already package this HAL**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 '
cd /home/dell/redroid-build/redroid16-src-cs
grep -nE "audio\\.primary|android\\.hardware\\.audio|primary_audio_policy_configuration|audio_policy_configuration" \
  device/redroid/redroid.mk device/redroid/manifest.xml
'
```

Expected:

- current Redroid product uses generic audio packaging
- the current product does not explicitly wire the `ranchu` tinyalsa HAL as the primary implementation

### Task 3: Add a failing packaging check before changing the product

**Files:**
- Create: `tests/redroid/test_guest4k_audio_product.py`

**Step 1: Write a failing test that describes the target packaging**

Add a test that reads a captured copy of `device/redroid/redroid.mk` and asserts that the product
packages:

- a `ranchu` primary audio HAL
- the needed audio policy XMLs from the `goldfish` audio tree

Minimal shape:

```python
from pathlib import Path


def test_redroid_product_declares_ranchu_audio_hal():
    text = Path("tmp/test-fixtures/redroid.mk").read_text()
    assert "android.hardware.audio@7.1-impl.ranchu" in text
```

**Step 2: Add the minimal fixture for the current product**

Create:

- `tmp/test-fixtures/redroid.mk`

by copying the current `device/redroid/redroid.mk` text into the fixture.

**Step 3: Run the test and verify it fails**

Run:

```bash
pytest tests/redroid/test_guest4k_audio_product.py -v
```

Expected:

- FAIL because the current fixture does not declare the `ranchu` primary HAL

### Task 4: Patch the Redroid product for a minimal `ranchu` audio trial

**Files:**
- Modify: remote `/home/dell/redroid-build/redroid16-src-cs/device/redroid/redroid.mk`
- Modify: remote `/home/dell/redroid-build/redroid16-src-cs/device/redroid/manifest.xml`

**Step 1: Back up the current source files**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 '
cd /home/dell/redroid-build/redroid16-src-cs/device/redroid
cp redroid.mk redroid.mk.bak-alsa-hal-$(date +%Y%m%d-%H%M%S)
cp manifest.xml manifest.xml.bak-alsa-hal-$(date +%Y%m%d-%H%M%S)
'
```

Expected:

- timestamped backups exist

**Step 2: Add the minimal product package wiring**

Update `device/redroid/redroid.mk` so the product packages:

- `android.hardware.audio@7.1-impl.ranchu`
- `android.hardware.audio.legacy@7.1-impl.ranchu`
- `audio.r_submix.default`
- `audio.bluetooth.default`

and uses the `goldfish` audio policy XML set as the installed policy configuration.

Do not change unrelated graphics or networking packages.

**Step 3: Adjust manifest only if the build or runtime selection still requires explicit audio HAL declaration**

Expected:

- prefer the smallest manifest delta possible
- do not reintroduce old unrelated HIDL declarations unless the build proves they are needed

### Task 5: Mirror the new packaging in local regression tests

**Files:**
- Modify: `tmp/test-fixtures/redroid.mk`
- Modify: `tests/redroid/test_guest4k_audio_product.py`

**Step 1: Update the fixture**

Add the exact product lines introduced in the source patch.

**Step 2: Run the packaging test and verify it passes**

Run:

```bash
pytest tests/redroid/test_guest4k_audio_product.py -v
```

Expected:

- PASS

### Task 6: Build the trial audio image on `104`

**Files:**
- Validate: remote `/home/dell/redroid-build/redroid16-src-cs`

**Step 1: Run the minimal build for the audio stack**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 '
bash --login -c "
cd /home/dell/redroid-build/redroid16-src-cs &&
source build/envsetup.sh &&
lunch redroid_arm64_only-bp2a-userdebug &&
m android.hardware.audio@7.1-impl.ranchu android.hardware.audio.legacy@7.1-impl.ranchu
"'
```

Expected:

- build succeeds for the audio HAL modules

**Step 2: If the product wiring affects image packaging, rebuild the image artifact**

Run:

```bash
sshpass -p 'root@123' ssh -o StrictHostKeyChecking=no dell@192.168.1.104 '
bash --login -c "
cd /home/dell/redroid-build/redroid16-src-cs &&
source build/envsetup.sh &&
lunch redroid_arm64_only-bp2a-userdebug &&
m
"'
```

Expected:

- vendor image or system image rebuilds with the new audio contents

### Task 7: Deploy the trial image to `107`

**Files:**
- Validate: `redroid/scripts/redroid_guest4k_107.sh`

**Step 1: Copy the built artifacts or image to the host**

Run the minimal deploy path used by the current Guest4K image flow.

Expected:

- `107` receives the new trial artifact

**Step 2: Restart Guest4K on the new image**

Run:

```bash
export SUDO_PASS=123123
zsh redroid/scripts/redroid_guest4k_107.sh restart
zsh redroid/scripts/redroid_guest4k_107.sh verify
```

Expected:

- guest boots
- ADB and VNC return

### Task 8: Verify the new HAL is live before testing apps

**Files:**
- Validate: none

**Step 1: Confirm `android.hardware.audio.service` maps the new HAL**

Run:

```bash
sshpass -p '123123' ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  "ssh -i /home/wjq/vm4k/ubuntu24k/guest_key -o StrictHostKeyChecking=no -p 2222 wjq@127.0.0.1 \
   'echo 123123 | sudo -S sh -lc \"pid=\$(pidof android.hardware.audio.service); grep -E \\\"audio.primary|ranchu|tinyalsa|goldfish\\\" /proc/\$pid/maps\"'"
```

Expected:

- runtime no longer maps `audio.primary.redroid.so`
- runtime maps the new `ranchu` audio implementation

**Step 2: Confirm Android opens PCM during playback**

Run while Douyin is actively playing:

```bash
sshpass -p '123123' ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  "ssh -i /home/wjq/vm4k/ubuntu24k/guest_key -o StrictHostKeyChecking=no -p 2222 wjq@127.0.0.1 \
   'echo 123123 | sudo -S lsof /dev/snd/pcmC0D0p'"
```

Expected:

- Android audio process holds the PCM device

### Task 9: Verify end-to-end host audio behavior

**Files:**
- Validate: none

**Step 1: Observe PipeWire during active playback**

Run:

```bash
sshpass -p '123123' ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 '
pactl list sink-inputs 2>/dev/null | sed -n "/node.name = \"qemu-system-aarch64\"/,+20p"
echo ---
pw-cli info 56
'
```

Expected:

- QEMU stream is no longer idle/corked during playback

**Step 2: Perform audible validation**

With Douyin feed video playing in VNC:

- confirm the host speakers now play app audio

Expected:

- sound is reproducible and corresponds to the app content

### Task 10: Record the new state

**Files:**
- Modify: `README.md`
- Modify: `docs/guides/install-china-apps.md`
- Modify: `docs/plans/2026-03-20-redroid-guest4k-root-cause.md`

**Step 1: If the ALSA HAL trial succeeds**

Document:

- the chosen HAL
- the runtime verification evidence
- the host/guest commands used to prove it

**Step 2: If the trial fails**

Document the exact stop point:

- build failure
- runtime still loading the old HAL
- new HAL loaded but still not opening PCM
- PCM open succeeds but no host audio

The repository should record the exact boundary, not rely on terminal history.
