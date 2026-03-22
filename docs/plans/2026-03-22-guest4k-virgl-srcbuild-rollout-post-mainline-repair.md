# Guest4K Virgl Srcbuild Rollout Post-Mainline Repair Plan

Goal: Repair the explicit `virgl-srcbuild-rollout` / `virgl-srcbuild-rollback`
workflow after the default Guest4K mainline promotion changed the real
standard-port owner to `redroid16kguestprobe`.

Architecture: Keep the preserved virgl control container as the rollout clone
source, but make rollout handoff and rollback restoration target the current
standard mainline container instead of the old preserved control container.

Tech Stack: zsh operator script, guest-rootful podman, Python `unittest`

## Task 1: Lock the post-promotion contract in tests

Files:

- Modify: `tests/redroid/test_redroid_guest4k_107.py`

Add focused dry-run coverage asserting that:

- rollout prechecks `redroid16kguestprobe`
- rollout stops `redroid16kguestprobe` before starting the rollout container
- rollback starts `redroid16kguestprobe`

Run the focused tests first and confirm they fail.

## Task 2: Implement the minimal handoff and restore fix

Files:

- Modify: `redroid/scripts/redroid_guest4k_107.sh`

Make these changes only:

- rollout prechecks both the preserved control container and
  `redroid16kguestprobe`
- rollout stops `redroid16kguestprobe` before starting the rollout container
- auto-restore restarts `redroid16kguestprobe`
- explicit rollback restarts `redroid16kguestprobe`

Do not change the rollout clone source or the health gate.

## Task 3: Verify local behavior

Run:

```bash
python3 -m unittest \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_virgl_srcbuild_rollout_dry_run_stops_current_standard_mainline_before_handoff \
  tests.redroid.test_redroid_guest4k_107.RedroidGuest4K107ScriptTest.test_virgl_srcbuild_rollback_dry_run_restores_standard_mainline_without_deleting_rollout_data
python3 -m unittest tests.redroid.test_redroid_guest4k_107
```

Expected:

- focused tests pass
- full Guest4K suite passes

## Task 4: Verify live behavior and record the residual loose end

Run:

```bash
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh virgl-srcbuild-rollout
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh virgl-srcbuild-rollback
sleep 10
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh verify
SUDO_PASS='codex-nopass' zsh redroid/scripts/redroid_guest4k_107.sh status
```

Capture:

- whether rollout reaches `ROLLOUT_ACTIVE`
- whether rollback restores `redroid16kguestprobe`
- whether the standard mainline verifies green after rollback settles
- whether the older `exec: No such file or directory` stderr still appears
