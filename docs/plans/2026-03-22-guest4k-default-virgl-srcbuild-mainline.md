# Guest4K Default Virgl Srcbuild Mainline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Promote the validated Guest4K srcbuild virgl image to the default
`restart` path while preserving the old `alsa-hal-ranchu-exp2` line as an
explicit legacy fallback.

**Architecture:** Keep one shared restart implementation in
`redroid/scripts/redroid_guest4k_107.sh`, but make image selection explicit at
the action-dispatch layer. Default restart actions use the srcbuild virgl
image, new legacy restart actions use the old image, and rollout/rollback stay
unchanged.

**Tech Stack:** zsh, guest-rootful podman, Python `unittest`, Markdown

---

### Task 1: Add failing coverage for the new default and legacy restart actions

**Files:**
- Modify: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Write a failing test for the new default image**

Add a focused dry-run test that runs:

```python
result = self.run_script("--dry-run", "restart")
```

Assert that output contains:

- `localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322`
- `restarting guest Redroid container`

and does not contain:

- `--entrypoint /init localhost/redroid4k-root:alsa-hal-ranchu-exp2`

**Step 2: Run the focused test to verify it fails**

Run:

```bash
python3 -m unittest tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_restart_dry_run_uses_srcbuild_virgl_image_by_default
```

Expected: FAIL because `restart` still uses the old image.

**Step 3: Write failing tests for the legacy actions**

Add two dry-run tests:

```python
result = self.run_script("--dry-run", "restart-legacy")
result = self.run_script("--dry-run", "restart-legacy-preserve-data")
```

Assert that:

- both actions are accepted
- both use `localhost/redroid4k-root:alsa-hal-ranchu-exp2`
- the preserve-data variant does not remove `redroid-data`

**Step 4: Run the legacy tests to verify they fail**

Run:

```bash
python3 -m unittest \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_restart_legacy_dry_run_uses_legacy_image \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_restart_legacy_preserve_data_dry_run_keeps_volume_and_uses_legacy_image
```

Expected: FAIL because the actions do not exist yet.

**Step 5: Write a failing help-output test**

Add a dry-run help test asserting that usage now includes:

- `restart-legacy`
- `restart-legacy-preserve-data`

**Step 6: Run the help test to verify it fails**

Run:

```bash
python3 -m unittest tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_help_lists_legacy_restart_actions
```

Expected: FAIL because help output does not list the legacy actions yet.

### Task 2: Implement explicit image selection in the restart path

**Files:**
- Modify: `redroid/scripts/redroid_guest4k_107.sh`

**Step 1: Define explicit image defaults**

Add constants or env defaults for:

- the new default srcbuild virgl image
- the legacy fallback image

Keep `IMAGE=...` override support.

**Step 2: Refactor `restart_redroid()` to accept an image and preserve-data flag**

Recommended call shape:

```zsh
restart_redroid "${image}" "${preserve_data}"
```

Inside the function:

- use the passed image in `podman run`
- keep the existing graphics, audio, binderfs, ADB, boot-wait, and post-boot
  behavior unchanged
- log the selected image before launch

**Step 3: Add the new legacy actions to CLI parsing**

Update:

- `usage()`
- the action allowlist in `main()`
- the dispatch `case`

to include:

- `restart-legacy`
- `restart-legacy-preserve-data`

**Step 4: Wire all four restart-style actions**

Map actions as follows:

- `restart` -> new default image, non-preserved data
- `restart-preserve-data` -> new default image, preserved data
- `restart-legacy` -> legacy image, non-preserved data
- `restart-legacy-preserve-data` -> legacy image, preserved data

**Step 5: Run the focused tests and make them pass**

Run:

```bash
python3 -m unittest \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_restart_dry_run_uses_srcbuild_virgl_image_by_default \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_restart_legacy_dry_run_uses_legacy_image \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_restart_legacy_preserve_data_dry_run_keeps_volume_and_uses_legacy_image \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_help_lists_legacy_restart_actions
```

Expected: PASS.

### Task 3: Keep rollout/rollback coverage green

**Files:**
- Modify: `tests/redroid/test_redroid_guest4k_107.py` if any existing assertion
  assumes the old default image

**Step 1: Re-run the existing rollout/rollback-focused tests**

Run:

```bash
python3 -m unittest \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_virgl_srcbuild_rollout_dry_run_uses_clone_handoff_shape \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_virgl_srcbuild_rollout_dry_run_honors_override_env \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_virgl_srcbuild_rollback_dry_run_restores_control_without_deleting_preserved_data \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_help_lists_virgl_srcbuild_actions
```

Expected: PASS.

**Step 2: Adjust only broken assumptions that depend on the old default**

Do not change rollout/rollback behavior.

### Task 4: Update mainline documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/guides/guest4k-mainline-how-it-works.md`

**Step 1: Update README**

Change the mainline description so it states:

- default image is the srcbuild virgl image
- daily operator flow uses `restart`
- explicit fallback uses `restart-legacy`

**Step 2: Update the guide**

Change the guide so it states:

- the current default mainline is the srcbuild virgl line
- the old `ANGLE + SwiftShader` line is now legacy fallback / historical
  baseline
- the recommended fallback command is `restart-legacy`

**Step 3: Keep the docs operational, not speculative**

Do not rewrite unrelated sections.

### Task 5: Verify locally and live

**Files:**
- No file changes required

**Step 1: Run the full Guest4K unit-test suite**

Run:

```bash
python3 -m unittest tests.redroid.test_redroid_guest4k_107
```

Expected: PASS.

**Step 2: Run a live smoke with the new default**

Run:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh restart
zsh redroid/scripts/redroid_guest4k_107.sh verify
zsh redroid/scripts/redroid_guest4k_107.sh status
```

Expected:

- the container boots successfully
- status shows the new default image active
- verify remains green

**Step 3: Run a live smoke with the explicit legacy fallback**

Run:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh restart-legacy
zsh redroid/scripts/redroid_guest4k_107.sh verify
zsh redroid/scripts/redroid_guest4k_107.sh status
```

Expected:

- the legacy line still boots
- verify remains usable enough to confirm recovery
- status shows the legacy image active

**Step 4: Restore the preferred mainline**

Run:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh restart
zsh redroid/scripts/redroid_guest4k_107.sh status
```

Expected: the srcbuild virgl image is active again.

### Task 6: Record the result

**Files:**
- Create: `docs/plans/2026-03-22-guest4k-default-virgl-srcbuild-mainline-result.md`

**Step 1: Write a short result note**

Record:

- unit-test result
- default-mainline live smoke result
- legacy-fallback live smoke result
- final restored active image

**Step 2: Commit when requested**

Stage only the files for this change and use a commit message that includes the
required `Co-authored-by: Codex <noreply@openai.com>` trailer exactly once.
