# Redroid Workspace Reorganization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reorganize the local Redroid assets into stable paths, document the workspace clearly, and harden the default operator script so app launches do not regress after container restart.

**Architecture:** Keep upstream `m1n1` files in place and add a dedicated local Redroid layer under `redroid/`, `docs/guides/`, and `tests/redroid/`. Update the operator script, test, and README together so paths and documented workflows stay consistent.

**Tech Stack:** `zsh`, `python3`, `adb`, `podman`, `ssh`, `unittest`, Markdown

---

### Task 1: Create the durable Redroid documentation surface

**Files:**
- Create: `docs/plans/2026-03-19-redroid-workspace-reorg-design.md`
- Create: `docs/plans/2026-03-19-redroid-workspace-reorg.md`
- Create: `docs/guides/install-china-apps.md`
- Create: `docs/guides/redroid-vs-real-phone.md`

**Step 1: Write the design and plan docs**

Capture the approved repository layout, why the Redroid files move out of `tmp/`, and how the permission workaround should be solidified.

**Step 2: Copy the Chinese reference docs into stable guide filenames**

Preserve the content, but store it under guide paths that can be linked from the root README.

**Step 3: Verify the docs exist**

Run: `find docs -maxdepth 2 -type f | sort`

Expected: the new plan and guide files appear.

### Task 2: Move operator assets to the new Redroid layer

**Files:**
- Create: `redroid/scripts/redroid_root_safe_107.sh`
- Create: `redroid/scripts/redroid_resume_107.sh`
- Create: `redroid/tools/redroid_viewer.py`
- Create: `redroid/tools/redroid_ffplay.py`
- Create: `redroid/tools/elf_align16k.py`
- Delete: `tmp/redroid_root_safe_107.sh`
- Delete: `tmp/redroid_resume_107.sh`
- Delete: `tmp/redroid_viewer.py`
- Delete: `tmp/redroid_ffplay.py`
- Delete: `tmp/elf_align16k.py`

**Step 1: Copy files into their final directories**

Move the operational and helper files without changing upstream `m1n1` structure.

**Step 2: Update embedded paths**

Retarget help text, viewer launch paths, and any repo-local paths so they reference `redroid/` instead of `tmp/`.

**Step 3: Search for stale paths**

Run: `rg "tmp/redroid_|tmp/elf_align16k|/tmp/redroid_viewer.py" README.md docs redroid tests`

Expected: only intentional historical references remain, or no matches.

### Task 3: Harden the main operator script with the permission repair

**Files:**
- Modify: `redroid/scripts/redroid_root_safe_107.sh`

**Step 1: Write the failing test**

Extend the regression test to assert the dry-run restart path includes a repair for:

- `llndk.libraries.txt`
- `sanitizer.libraries.txt`

**Step 2: Run the test to verify failure**

Run: `python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v`

Expected: FAIL because the moved script path and repair logic are not implemented yet.

**Step 3: Implement the minimal script changes**

Add a post-start step that fixes the file modes after the container is up, and make dry-run output expose that command.

**Step 4: Run the test to verify pass**

Run: `python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v`

Expected: PASS.

### Task 4: Rewrite the root workspace README

**Files:**
- Modify: `README.md`
- Modify: `pytest.ini`
- Create: `tests/redroid/test_redroid_root_safe_107.py`
- Delete: `tests/python/test_redroid_root_safe_107.py`

**Step 1: Rewrite the README around the new layout**

Document:

- workspace purpose
- verified Redroid baseline
- current commands
- permission failure and fix
- VNC/input status
- guide and plan doc locations
- concise upstream `m1n1` build/use notes

**Step 2: Update test discovery**

Set `pytest.ini` to discover the broader `tests/` tree.

**Step 3: Move the regression test**

Retarget it to `redroid/scripts/redroid_root_safe_107.sh`.

### Task 5: Verify the reorganization

**Files:**
- Validate: `README.md`
- Validate: `redroid/scripts/redroid_root_safe_107.sh`
- Validate: `tests/redroid/test_redroid_root_safe_107.py`

**Step 1: Run the regression test**

Run: `python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v`

Expected: PASS.

**Step 2: Dry-run the operator script**

Run: `zsh redroid/scripts/redroid_root_safe_107.sh --dry-run restart`

Expected: prints the bridge-network startup path and the permission repair commands.

**Step 3: Search for stale references**

Run: `rg "tmp/redroid_|tests/python/test_redroid_root_safe_107.py" README.md docs redroid tests`

Expected: no active-path references remain outside historical plan docs.
