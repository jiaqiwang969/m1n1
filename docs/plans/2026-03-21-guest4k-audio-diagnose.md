# Guest4K Audio Diagnose Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a dedicated Guest4K `audio-diagnose` operator action that captures the current Android, guest ALSA, and host PipeWire audio surfaces in one place.

**Architecture:** Keep the change narrow and observational. Extend the existing `redroid_guest4k_107.sh` operator with one new action that reuses the current SSH, guest SSH, and ADB helpers, and add dry-run regression coverage that locks the intended output surfaces. Do not change QEMU, Android images, or runtime parameters in this pass.

**Tech Stack:** zsh, ssh, adb, PipeWire, ALSA, Python `unittest`, Markdown

---

### Task 1: Lock the new Guest4K audio diagnose surface in tests

**Files:**
- Modify: `tests/redroid/test_redroid_guest4k_107.py`
- Test: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Write the failing test**

Add a dry-run regression test for `audio-diagnose` that asserts the script surfaces:

- guest `/dev/snd`
- guest `/proc/asound/cards`
- guest `aplay -l`
- Android `dumpsys media.audio_flinger`
- Android `dumpsys audio`
- host `pactl list sink-inputs`
- host `pw-cli info`

**Step 2: Run test to verify it fails**

Run:

```bash
python3 -m pytest tests/redroid/test_redroid_guest4k_107.py -k audio_diagnose -v
```

Expected: FAIL because the action does not exist yet.

**Step 3: Write minimal implementation**

Add a dedicated `audio-diagnose` action to `redroid/scripts/redroid_guest4k_107.sh`.

**Step 4: Run test to verify it passes**

Run:

```bash
python3 -m pytest tests/redroid/test_redroid_guest4k_107.py -k audio_diagnose -v
```

Expected: PASS

### Task 2: Keep operator docs aligned with the Guest4K mainline

**Files:**
- Modify: `README.md`
- Modify: `redroid/scripts/redroid_guest4k_107.sh`

**Step 1: Update the usage surface**

Add `audio-diagnose` to the script help text and supported actions list.

**Step 2: Update the mainline README flow**

Document `audio-diagnose` as the primary runtime inspection entry point for Guest4K audio debugging.

**Step 3: Keep the wording narrow**

Describe it as a diagnosis tool for the already-working Guest4K path, not as a new architecture branch.

### Task 3: Verify the implementation with fresh evidence

**Files:**
- Test: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Run the focused script tests**

Run:

```bash
python3 -m pytest tests/redroid/test_redroid_guest4k_107.py -k 'audio_diagnose or douyin_diagnose' -v
```

Expected: PASS

**Step 2: Run the full Guest4K test file**

Run:

```bash
python3 -m pytest tests/redroid/test_redroid_guest4k_107.py -v
```

Expected: PASS

**Step 3: Run the real operator action on `107`**

Run:

```bash
SUDO_PASS=123123 zsh redroid/scripts/redroid_guest4k_107.sh audio-diagnose
```

Expected: output shows Android playback state, guest ALSA device visibility, and host PipeWire/QEMU node state in one command.
