# Douyin libtnet 16K RELRO Fix Design

## Context

Douyin now launches on the Redroid baseline and on `phone-mode`, passes the Android 16 `pageSizeCompat` gate, and reaches its own privacy guide UI.

The first reproducible fatal step is after tapping `同意`. At that point Douyin requests notification permission and initializes its push / network stack. The process then dies with `SIGSEGV` while loading `libtnet-3.1.14.so` in `JNI_OnLoad`.

The key tombstone evidence is:

- thread: `UPush-1`
- top native frames: `libc.so` -> `libtnet-3.1.14.so` -> `JNI_OnLoad`
- fault address lands in `libtnet-3.1.14.so`
- the faulted offset maps back to `.data`
- runtime memory map shows that page as `r--`, not `rw-`

This points to a 16 KB page-size compatibility issue around `GNU_RELRO`: a page that contains both RELRO-covered bytes and ordinary writable `.data` is being protected read-only at 16 KB granularity.

## Goal

Add a small repository-local ELF utility that:

- detects when a `GNU_RELRO` segment becomes unsafe on a 16 KB page system
- trims or disables only the unsafe portion of RELRO
- leaves already-safe ELFs untouched
- is testable without depending on the live host

Then use that tool to patch Douyin's installed `libtnet-3.1.14.so` for a real-device validation.

## Options Considered

### Option 1: Keep debugging container props and app-facing spoofing

Pros:
- no ELF tooling work

Cons:
- current evidence already shows the crash is inside `libtnet-3.1.14.so`
- does not address the fact that `.data` is mapped read-only
- likely wastes more time on unrelated runtime shaping

### Option 2: Add a focused ELF RELRO fix tool and patch only the offending library

Pros:
- matches the current root-cause evidence
- smallest change that can directly change the crashing memory protection
- reusable for other China-app native libraries on 16 KB systems
- easy to validate with a single before/after experiment

Cons:
- reduces RELRO hardening for the patched library
- needs careful test coverage to avoid corrupting arbitrary ELFs

### Option 3: Repackage and resign the whole APK immediately

Pros:
- could produce a distributable patched APK later

Cons:
- brings in signing and install churn before proving the native hypothesis
- much larger blast radius than needed for the next experiment

Recommended: Option 2.

## Approved Design

### Tool surface

Create `redroid/tools/elf_relro16k.py` with two actions:

- `check <input.elf>`
- `patch <input.elf> <output.elf>`

The tool will target 64-bit little-endian ELF shared libraries, which matches the Redroid / Douyin arm64 case.

### Detection rule

For each `PT_GNU_RELRO` program header:

1. compute the effective protected range on a 16 KB page system
2. scan allocated writable sections
3. if writable bytes exist in the protected page range outside the nominal RELRO byte range, flag the ELF as unsafe

This is the exact pattern seen in `libtnet-3.1.14.so`:

- nominal RELRO ends at `0x57000`
- `.data` begins at `0x57000`
- both still live inside the same 16 KB page

### Patch rule

Patch only the affected `PT_GNU_RELRO` header:

- keep the original ELF layout
- reduce `p_filesz` and `p_memsz` to the last page-safe boundary
- if no safe RELRO range remains, set both sizes to `0`

For `libtnet-3.1.14.so`, this should disable RELRO entirely for that segment, because the first protected page already overlaps writable `.data`.

### Testing

Add a unit test that builds a tiny synthetic ELF fixture with:

- a writable `PT_LOAD`
- a `PT_GNU_RELRO`
- a `.data` section that starts at the end of RELRO but in the same 16 KB page

The failing expectation is:

- after patching, the RELRO sizes are zeroed

### Live verification

After the tool passes locally:

1. patch the pulled `libtnet-3.1.14.so`
2. replace the installed copy on `192.168.1.107`
3. relaunch Douyin
4. tap through privacy consent again
5. verify whether the app survives the notification-permission step

## Validation Update

The first implementation round produced useful evidence, but it did not fix the runtime:

- package-manager-side page-size compat is already enabled on the live host: `pageSizeCompat=36`
- a RELRO-zero-only patch still reproduces the same `libtnet-3.1.14.so` crash
- a second experiment that also shifted the writable `PT_LOAD` file offset by `+0x4000` still reproduces the same crash
- the newer tombstone still lands on `UPush-1` in `JNI_OnLoad`, with the fault address in `.data`
- local disassembly shows `JNI_OnLoad` calling a helper at `0x66c4`; the crashing path reaches `0x6700`, which performs `pthread_mutex_lock` on state located in the first `.data` page at `0x67000`
- the first page of the writable load remains effectively read-only in the observed mapping

Current conclusion: the original RELRO-overlap hypothesis was directionally useful, but RELRO trimming alone is not enough. The next 16 KB iteration has to focus on the writable-load mapping itself, or the project should pivot to a 4 KB guest if the immediate goal is simply to get Douyin running.

## Next Step

Implement the tool with TDD, then run a single live validation against the known crashing library before deciding whether to automate deployment in `redroid_root_safe_107.sh`.
