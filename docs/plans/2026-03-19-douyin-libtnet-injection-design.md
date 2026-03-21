# Douyin libtnet Injection Design

## Context

The current Redroid-on-Asahi baseline is stable enough to boot Android 16, drive VNC input, pass the Douyin `pageSizeCompat=36` gate, and reach the app's privacy flow.

The active native blocker is still `libtnet-3.1.14.so` on the `UPush-1` thread during `JNI_OnLoad`, but there is a new operational gap:

- the live device currently reports the installed `libtnet-3.1.14.so` as the original binary
- its hash matches the local extracted original library
- it does not match either local patched candidate

That means the current workspace does not yet have a reliable "patched libtnet is actually installed on the live device" workflow. Until that is fixed, later crash observations are not strong evidence about whether the patch itself helps.

## Goal

Add a repeatable Douyin-native-library workflow that can:

- install a chosen patched `libtnet-3.1.14.so` into the current Douyin install directory
- verify that the live device is really using the patched binary
- restore the original library cleanly
- integrate with the existing operator script without disturbing the stable 16 KB baseline

## Options Considered

### Option 1: Keep using ad-hoc shell commands

Pros:

- fastest for one-off experiments
- no script work required

Cons:

- state is hard to audit after container restart or app reinstall
- easy to think a patch is installed when the device still has the original library
- no durable verification surface for future experiments

### Option 2: Add a fully generic native-library patch framework

Pros:

- flexible for future apps and libraries

Cons:

- too large for the current need
- adds abstraction before the current Douyin path is stable

### Option 3: Add a narrow Douyin `libtnet` install / verify / restore flow

Pros:

- solves the real immediate problem
- reuses the existing operator script entrypoint
- keeps the surface small and testable
- still allows manual fallback commands for debugging

Cons:

- specific to Douyin and `libtnet`
- may need a later generalization if more libraries are patched

Recommended: Option 3.

## Approved Design

### Command surface

Extend `redroid/scripts/redroid_root_safe_107.sh` with explicit Douyin-native actions:

- `douyin-libtnet-status`
- `douyin-libtnet-install`
- `douyin-libtnet-verify`
- `douyin-libtnet-restore`

These actions should stay separate from:

- baseline runtime actions such as `restart` / `verify`
- package-manager compat actions such as `douyin-compat`
- app-facing runtime shaping such as `phone-mode`

### Patch source selection

The script should default to a local patched library path under the current workspace, while allowing an override through an environment variable.

Default candidates should be explicit and local:

- `tmp/douyin/patched/libtnet-3.1.14.so`
- or, when selected by env override, `tmp/douyin/patched/libtnet-3.1.14.clean16k.so`

This keeps patch selection auditable and prevents the script from silently using whatever happens to be on the remote host.

### Install flow

`douyin-libtnet-install` should:

1. ensure ADB root access on the live device
2. resolve the current Douyin APK path with `pm path`
3. derive the active `lib/arm64` directory from that package path
4. read and report the current live library hash before changing anything
5. pull or copy the original live library into a deterministic remote backup path
6. stage the chosen patched library onto the remote host
7. replace the live library in the active install directory
8. fix executable permissions if needed
9. read back the live hash and ELF headers to prove the replacement landed
10. force-stop Douyin so the next launch is a clean repro

The install action should fail fast if:

- Douyin is not installed
- the local patch file is missing
- the live install directory cannot be resolved
- post-install verification still shows the original hash

### Verification flow

`douyin-libtnet-status` and `douyin-libtnet-verify` should provide a compact audit surface:

- current Douyin install path
- current live `libtnet` hash
- whether that hash matches the original local library
- whether that hash matches the configured patch candidate
- current `PT_LOAD` / `PT_GNU_RELRO` values for the live binary

The point is not just "file exists", but "the live binary is provably the intended one".

### Restore flow

`douyin-libtnet-restore` should restore the original library from the stored backup, then re-run the same hash and ELF verification.

This gives the workspace a clean rollback path when a patch is known-bad or when later experiments need to start from the untouched library.

### Testing and documentation

Local tests should cover:

- dry-run command surface for the new actions
- patched-library path selection
- remote backup and verification steps appearing in dry-run output

Documentation should record:

- why this flow exists
- that live verification showed the device was still on the original `libtnet`
- that future crash conclusions must be based on a verified patched-live state

## Next Step

Write a narrow implementation plan, then add the failing script tests before changing the operator script.
