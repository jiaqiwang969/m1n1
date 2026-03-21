# Guest4K Default Image Alignment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the Guest4K operator default image match the image that is currently verified in the real runtime.

**Architecture:** Update the Guest4K operator script default image, lock that behavior with a dry-run regression test, and sync the current operator-facing docs. Keep historical plan documents unchanged.

**Tech Stack:** zsh script, pytest/unittest dry-run regression tests, Markdown docs

---

### Task 1: Lock the new default image in tests

**Files:**
- Modify: `tests/redroid/test_redroid_guest4k_107.py`
- Test: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Write the failing test**

Change the existing dry-run assertion so the default image must be `localhost/redroid4k-root:alsa-hal-ranchu-exp2`.

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/redroid/test_redroid_guest4k_107.py -k isolated_guest_redroid_shape -v`

Expected: FAIL because the script still defaults to the old image tag.

**Step 3: Write minimal implementation**

Update the default `IMAGE` value in `redroid/scripts/redroid_guest4k_107.sh`.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/redroid/test_redroid_guest4k_107.py -k isolated_guest_redroid_shape -v`

Expected: PASS

### Task 2: Sync the current operator docs

**Files:**
- Modify: `README.md`
- Modify: `docs/guides/install-china-apps.md`

**Step 1: Update current mainline references**

Replace current-user-facing default image references with `localhost/redroid4k-root:alsa-hal-ranchu-exp2`.

**Step 2: Document the preserve-data recovery path**

Add `restart-preserve-data` where current operator usage is described.

**Step 3: Keep history separated**

Do not rewrite old `docs/plans/*.md` records. If needed, describe earlier tags as historical context only in current docs.

### Task 3: Verify the full change set

**Files:**
- Test: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Run the full Guest4K script test suite**

Run: `python3 -m pytest tests/redroid/test_redroid_guest4k_107.py -v`

Expected: PASS

**Step 2: Re-run live runtime checks if needed**

Run:

```bash
SUDO_PASS=123123 IMAGE=localhost/redroid4k-root:alsa-hal-ranchu-exp2 \
zsh redroid/scripts/redroid_guest4k_107.sh restart-preserve-data
```

Expected: guest restarts without deleting app data.

**Step 3: Confirm guest and app state**

Run:

```bash
ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null \
   -i /home/wjq/vm4k/ubuntu24k/guest_key -p 2222 wjq@127.0.0.1 'getenforce'"
```

Expected: `Permissive`

Run:

```bash
ssh -o StrictHostKeyChecking=no wjq@192.168.1.107 \
  "adb connect 127.0.0.1:5556 >/dev/null 2>&1 || true; \
   adb -s 127.0.0.1:5556 shell am start -W -n com.ss.android.ugc.aweme/.splash.SplashActivity"
```

Expected: `Status: ok` and `Activity: com.ss.android.ugc.aweme/.main.MainActivity`
