# Douyin libtnet Runtime Copy Sync Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the Douyin `libtnet` workflow verify and manage both the APK install copy and the runtime `app_librarian` copy so live experiments touch the library Douyin actually loads.

**Architecture:** Extend `redroid/scripts/redroid_root_safe_107.sh` from a single-path `/data/app/.../lib/arm64/libtnet-3.1.14.so` tool into a two-surface audit/install/restore workflow. The script should enumerate runtime copies under `app_librarian`, report inode/hash differences, and replace existing runtime copies alongside the APK copy while preserving a deterministic rollback path.

**Tech Stack:** `zsh`, `adb`, `ssh`, existing Redroid operator script tests under `unittest`, Markdown docs.

---

### Task 1: Add failing tests for runtime-copy visibility

**Files:**
- Modify: `tests/redroid/test_redroid_root_safe_107.py`
- Modify: `redroid/scripts/redroid_root_safe_107.sh`

**Step 1: Write the failing test**

Add a dry-run test asserting `douyin-libtnet-verify` now exposes both the APK path and the runtime `app_librarian` path surface.

```python
def test_douyin_libtnet_verify_dry_run_shows_runtime_copy_audit_surface(self) -> None:
    result = subprocess.run(
        ["zsh", str(SCRIPT), "--dry-run", "douyin-libtnet-verify"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
    stdout = result.stdout
    self.assertIn("app_librarian", stdout)
    self.assertIn("inode", stdout)
    self.assertIn("sha256sum", stdout)
```

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/redroid/test_redroid_root_safe_107.py -k runtime_copy_audit_surface -v`

Expected: FAIL because the current script does not mention `app_librarian`.

**Step 3: Write minimal implementation**

Teach the script's verify/status output to print both path classes and to include inode/hash inspection commands for runtime copies.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/redroid/test_redroid_root_safe_107.py -k runtime_copy_audit_surface -v`

Expected: PASS

### Task 2: Add failing tests for install/restore touching runtime copies

**Files:**
- Modify: `tests/redroid/test_redroid_root_safe_107.py`
- Modify: `redroid/scripts/redroid_root_safe_107.sh`

**Step 1: Write the failing test**

Add dry-run assertions that install and restore workflows mention `app_librarian`, backup handling, and permission restoration.

```python
def test_douyin_libtnet_install_dry_run_targets_runtime_copies(self) -> None:
    ...
    self.assertIn("app_librarian", stdout)
    self.assertIn("cp -p", stdout)
    self.assertIn("chown", stdout)
```

```python
def test_douyin_libtnet_restore_dry_run_targets_runtime_copies(self) -> None:
    ...
    self.assertIn("app_librarian", stdout)
    self.assertIn("cp -p", stdout)
```

**Step 2: Run tests to verify they fail**

Run: `python3 -m pytest tests/redroid/test_redroid_root_safe_107.py -k "targets_runtime_copies" -v`

Expected: FAIL because current install/restore only handle `/data/app`.

**Step 3: Write minimal implementation**

Add runtime-copy enumeration plus install/restore logic that backs up and replaces each existing `app_librarian` copy alongside the APK copy.

**Step 4: Run tests to verify they pass**

Run: `python3 -m pytest tests/redroid/test_redroid_root_safe_107.py -k "targets_runtime_copies" -v`

Expected: PASS

### Task 3: Refine the operator script behavior

**Files:**
- Modify: `redroid/scripts/redroid_root_safe_107.sh`

**Step 1: Implement path discovery helpers**

Add helpers that:
- resolve the APK copy path from `pm path`
- enumerate `app_librarian/*/libtnet-3.1.14.so`
- print inode/hash state for all observed copies

**Step 2: Implement runtime-aware install**

Use a remote shell block that:
- backs up the APK copy once
- stages the chosen patch
- replaces the APK copy
- iterates existing runtime copies and replaces each with the staged file
- restores owner/mode for app-owned files
- force-stops Douyin after replacement

**Step 3: Implement runtime-aware restore**

Use the stored backups to restore the APK copy and any backed-up runtime copies.

**Step 4: Keep dry-run readable**

Ensure `--dry-run` prints the actual remote commands for runtime-copy handling instead of silently omitting them.

### Task 4: Update docs to reflect the corrected experiment boundary

**Files:**
- Modify: `README.md`
- Modify: `docs/guides/install-china-apps.md`

**Step 1: Document the runtime-copy caveat**

State that `/data/app` and `app_librarian` are distinct copies and that experiments are only valid if both surfaces are inspected.

**Step 2: Update operator workflow**

Describe the new status/install/restore semantics and the expected verification output.

**Step 3: Correct prior conclusions**

Reword the clean16k experiment note to say the earlier result was confounded because runtime copies were not yet managed explicitly.

### Task 5: Verify locally and on the live host

**Files:**
- No code changes expected

**Step 1: Run focused tests**

Run: `python3 -m pytest tests/redroid/test_redroid_root_safe_107.py -v`

Expected: PASS

**Step 2: Run one live audit**

Run: `zsh redroid/scripts/redroid_root_safe_107.sh douyin-libtnet-verify`

Expected: output includes both `/data/app/.../libtnet-3.1.14.so` and `app_librarian/.../libtnet-3.1.14.so` with inode/hash details.

**Step 3: Summarize remaining blocker**

Record whether the live baseline still points at patched `57bc...` in both surfaces and note that the next clean experiment can now target the actual runtime copy.
