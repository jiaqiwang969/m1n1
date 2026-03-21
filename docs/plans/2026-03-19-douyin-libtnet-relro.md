# Douyin libtnet 16K RELRO Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a focused ELF utility that detects and fixes 16 KB `GNU_RELRO` overlap with writable data, then validate it against Douyin's crashing `libtnet-3.1.14.so`.

**Architecture:** Implement a small Python ELF parser/patcher under `redroid/tools`, driven by a synthetic unittest fixture. The patch will shrink or zero only the unsafe `PT_GNU_RELRO` range, then the tool will be used for one real-device experiment on the installed Douyin native library.

**Tech Stack:** Python 3, `unittest`, ELF64 parsing with `struct`, `adb`, `ssh`

---

## Status Update

Latest validated state from the live host and local artifacts:

- `redroid/tools/elf_relro16k.py` and `tests/redroid/test_elf_relro16k.py` exist and were used for real-device experiments.
- the live device currently reports `pageSizeCompat=36` for `com.ss.android.ugc.aweme`, so package-level compat is no longer the active blocker
- the RELRO-zero patch still crashes in `libtnet-3.1.14.so`; see `tmp/tombstone_22.txt`
- the follow-up experiment that also shifted the second `PT_LOAD` file offset by `+0x4000` still crashes in `libtnet-3.1.14.so`; see `tmp/tombstone_23.txt`
- both experiments still fault on thread `UPush-1`, in `JNI_OnLoad`, with the fault landing in `.data`
- local disassembly now shows `JNI_OnLoad` calling a helper at `0x66c4`; the hot fault path reaches `0x6700`, which calls `pthread_mutex_lock` on state rooted in the first `.data` page at `0x67000`
- current interpretation: RELRO-only and file-offset-only surgery are both insufficient; the remaining issue is likely the first partial 16 KB page of the writable `PT_LOAD`
- `libsscronet.so` remains a secondary candidate from earlier heuristics, but the current RELRO checker does not flag it as the same overlap pattern

### Task 1: Add the failing RELRO-overlap test

**Files:**
- Create: `tests/redroid/test_elf_relro16k.py`
- Test: `tests/redroid/test_elf_relro16k.py`

**Step 1: Write the failing test**

Create a synthetic ELF fixture where:

- `PT_GNU_RELRO` ends exactly where `.data` begins
- both still occupy the same 16 KB page

Assert that running the patch tool produces an output ELF whose RELRO `p_filesz` and `p_memsz` are both `0`.

**Step 2: Run test to verify it fails**

Run:

```bash
python3 -m unittest tests/redroid/test_elf_relro16k.py -v
```

Expected: FAIL because `redroid/tools/elf_relro16k.py` does not exist yet.

### Task 2: Implement the minimal ELF tool

**Files:**
- Create: `redroid/tools/elf_relro16k.py`

**Step 1: Parse ELF64 little-endian headers**

Read:

- ELF header
- program headers
- section headers
- section-string table

Reject unsupported formats early.

**Step 2: Detect unsafe RELRO overlap**

Implement a helper that:

- expands RELRO to 16 KB protected pages
- finds allocated writable sections that fall into those pages outside nominal RELRO bytes
- returns the first conflicting section/range

**Step 3: Patch only the affected RELRO entry**

For each unsafe RELRO entry:

- compute the last safe boundary
- rewrite `p_filesz` / `p_memsz`
- preserve the rest of the file unchanged

**Step 4: Re-run the focused test**

Run:

```bash
python3 -m unittest tests/redroid/test_elf_relro16k.py -v
```

Expected: PASS.

### Task 3: Run broader local verification

**Files:**
- Modify: none

**Step 1: Run existing script tests too**

Run:

```bash
python3 -m unittest tests/redroid/test_redroid_root_safe_107.py -v
python3 -m unittest tests/redroid/test_elf_relro16k.py -v
```

**Step 2: Run a syntax-level check**

Run:

```bash
python3 redroid/tools/elf_relro16k.py check tmp/douyin/extract/lib/arm64-v8a/libtnet-3.1.14.so
```

Expected:

- unittests pass
- the tool reports unsafe RELRO overlap for `libtnet-3.1.14.so`

### Task 4: Validate against the live host

**Files:**
- Modify: none

**Step 1: Produce a patched library locally**

Run:

```bash
python3 redroid/tools/elf_relro16k.py patch \
  tmp/douyin/extract/lib/arm64-v8a/libtnet-3.1.14.so \
  tmp/douyin/patched/libtnet-3.1.14.so
```

**Step 2: Replace the installed library on the device**

Use `ssh` + `adb root`/`adb push` to replace the library under the installed Douyin app directory.

**Step 3: Reproduce the original crash path**

Launch Douyin, tap `同意`, and observe whether it still dies while loading `libtnet-3.1.14.so`.

**Step 4: Capture verification evidence**

Collect:

- current screenshot
- `logcat -b crash`
- latest tombstone, if any

Expected:

- no `libtnet-3.1.14.so` `JNI_OnLoad` crash on the old fault path

### Task 5: Update docs with the new blocker/fix path

**Files:**
- Modify: `README.md`
- Modify: `docs/guides/install-china-apps.md`

**Step 1: Document the real blocker**

Replace stale references to `libttmplayer.so` as the current primary blocker.

**Step 2: Record the validated workaround if the experiment succeeds**

Document:

- what was patched
- why 16 KB RELRO caused the crash
- where the tool lives

### Task 6: Commit

**Step 1: Commit the work**

```bash
git add docs/plans/2026-03-19-douyin-libtnet-relro-design.md docs/plans/2026-03-19-douyin-libtnet-relro.md redroid/tools/elf_relro16k.py tests/redroid/test_elf_relro16k.py README.md docs/guides/install-china-apps.md
git commit -m "feat: add 16k relro fixer for douyin native libs"
```
