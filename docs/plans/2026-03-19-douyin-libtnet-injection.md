# Douyin libtnet Injection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a repeatable install / verify / restore workflow for a patched Douyin `libtnet-3.1.14.so` so live crash testing on the 16 KB Redroid host is based on a provably patched library.

**Architecture:** Extend the existing Redroid operator script with narrow Douyin-specific native-library actions. The script will stage a chosen local patch to the remote host, resolve the live Douyin install directory, replace the installed library, and then verify the live hash plus ELF header shape. A restore action will roll the library back from a captured original backup.

**Tech Stack:** `zsh`, Python 3, `unittest`, `ssh`, `scp`, `adb`

---

### Task 1: Add failing dry-run tests for the new command surface

**Files:**
- Modify: `tests/redroid/test_redroid_root_safe_107.py`

**Step 1: Write the failing tests**

Add tests that assert:

- `--dry-run douyin-libtnet-install` exits `0`
- dry-run output mentions the configured local patch path
- dry-run output mentions resolving the Douyin install path
- dry-run output mentions backing up the live `libtnet`
- dry-run output mentions post-install verification
- `--dry-run douyin-libtnet-verify` exits `0`
- `--dry-run douyin-libtnet-restore` exits `0`

**Step 2: Run test to verify it fails**

Run:

```bash
python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v
```

Expected: FAIL because the new Douyin `libtnet` actions do not exist yet.

### Task 2: Add the minimal script plumbing for patch selection

**Files:**
- Modify: `redroid/scripts/redroid_root_safe_107.sh`

**Step 1: Add patch-path constants**

Add explicit defaults for:

- the original local `libtnet` path
- the default patched `libtnet` path
- the remote staging path
- the remote backup directory

Also allow overriding the patched library path through an environment variable.

**Step 2: Add a helper that resolves the live Douyin library directory**

Use:

- `adb shell pm path`
- `dirname`

to derive the active `/data/app/.../lib/arm64` directory at runtime.

### Task 3: Implement install / verify / restore actions

**Files:**
- Modify: `redroid/scripts/redroid_root_safe_107.sh`

**Step 1: Implement `douyin-libtnet-status` and `douyin-libtnet-verify`**

Print:

- current APK path
- current live `libtnet` path
- current live `sha256`
- configured original and patched `sha256`
- live ELF load / RELRO summary

**Step 2: Implement `douyin-libtnet-install`**

Make the script:

- fail if the local patch file is missing
- copy the patch to the remote host
- back up the live original library
- replace the live library
- force-stop Douyin
- verify that the live hash now matches the patch

**Step 3: Implement `douyin-libtnet-restore`**

Make the script:

- restore from the remote backup
- verify that the live hash no longer matches the patch

### Task 4: Add a small Python helper for ELF header reporting

**Files:**
- Modify: `redroid/tools/elf_relro16k.py`
- Test: `tests/redroid/test_elf_relro16k.py`

**Step 1: Add a minimal machine-readable or compact summary mode**

Expose enough output to print:

- writable `PT_LOAD`
- `PT_GNU_RELRO`

for a target ELF without needing external `readelf`.

**Step 2: Add the failing test**

Assert the tool can summarize the synthetic test ELF's load and RELRO entries.

**Step 3: Run tests to verify failure, then pass**

Run:

```bash
python3 -m unittest tests/redroid/test_elf_relro16k.py -v
```

Expected:

- first run fails before implementation
- second run passes after the helper is added

### Task 5: Update operator docs

**Files:**
- Modify: `README.md`
- Modify: `docs/guides/install-china-apps.md`

**Step 1: Document the live-state gap**

Record that the live device was verified to still have the original `libtnet`, so earlier patch experiments were not yet backed by a persistent install workflow.

**Step 2: Document the new actions**

Add:

- `douyin-libtnet-status`
- `douyin-libtnet-install`
- `douyin-libtnet-verify`
- `douyin-libtnet-restore`

### Task 6: Run local verification

**Files:**
- Validate: `redroid/scripts/redroid_root_safe_107.sh`
- Validate: `redroid/tools/elf_relro16k.py`
- Validate: `tests/redroid/test_redroid_root_safe_107.py`
- Validate: `tests/redroid/test_elf_relro16k.py`

**Step 1: Run the relevant tests**

Run:

```bash
python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v
python3 -m unittest tests/redroid/test_elf_relro16k.py -v
```

**Step 2: Run dry-runs**

Run:

```bash
zsh redroid/scripts/redroid_root_safe_107.sh --dry-run douyin-libtnet-install
zsh redroid/scripts/redroid_root_safe_107.sh --dry-run douyin-libtnet-verify
zsh redroid/scripts/redroid_root_safe_107.sh --dry-run douyin-libtnet-restore
```

Expected:

- tests pass
- dry-run output shows the patch path, backup path, and verification workflow

### Task 7: Live verification on the remote host

**Files:**
- Modify: none

**Step 1: Capture the pre-install live state**

Run:

```bash
zsh redroid/scripts/redroid_root_safe_107.sh douyin-libtnet-status
```

Expected:

- the live hash matches the original local library

**Step 2: Install the patch**

Run:

```bash
zsh redroid/scripts/redroid_root_safe_107.sh douyin-libtnet-install
```

Expected:

- the live hash changes to the configured patch hash

**Step 3: Re-verify the live library**

Run:

```bash
zsh redroid/scripts/redroid_root_safe_107.sh douyin-libtnet-verify
```

Expected:

- live hash matches patch hash
- live ELF summary reflects the patched header values

**Step 4: Restore when needed**

Run:

```bash
zsh redroid/scripts/redroid_root_safe_107.sh douyin-libtnet-restore
```

Expected:

- live hash returns to the original library

### Task 8: Commit

**Step 1: Commit the work**

```bash
git add docs/plans/2026-03-19-douyin-libtnet-injection-design.md docs/plans/2026-03-19-douyin-libtnet-injection.md README.md docs/guides/install-china-apps.md redroid/scripts/redroid_root_safe_107.sh redroid/tools/elf_relro16k.py tests/redroid/test_redroid_root_safe_107.py tests/redroid/test_elf_relro16k.py
git commit -m "feat: add douyin libtnet injection workflow"
```
