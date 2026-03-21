# Redroid 4K Runtime Design

## Context

The current 16 KB Redroid baseline is stable enough for general bring-up, VNC input, and early Douyin launch flow, but Douyin still crashes in `libtnet-3.1.14.so` during native startup on the 16 KB guest.

The operator script already has a clean separation between:

- baseline `restart` / `verify` / `viewer`
- Douyin-specific `douyin-compat`
- app-facing `phone-mode`

The next pragmatic move is not deeper 16 KB ELF surgery first. It is to add a separate 4 KB Android runtime path that can be launched and tested without disturbing the known-good 16 KB baseline.

## Goal

Add an explicit 4 KB runtime path to the existing operator script so the workspace can:

- start a 4 KB Redroid guest from the remote host's existing upstream image
- keep its container name, data volume, and docs separate from the 16 KB path
- verify that the guest actually boots as the alternate route
- optionally use the same lightweight viewer workflow against the 4 KB ADB endpoint

## Options Considered

### Option 1: Replace the current 16 KB defaults with 4 KB values

Pros:
- smallest code delta

Cons:
- destroys the currently documented baseline
- makes it harder to compare 16 KB and 4 KB behavior
- raises the risk of accidental regressions in the only stable operator path

### Option 2: Add explicit 4 KB sibling actions

Pros:
- keeps the 16 KB flow untouched
- makes the runtime choice obvious at the command line
- fits the current script style
- easy to document and dry-run

Cons:
- duplicates some command-surface names
- requires a small amount of profile plumbing

### Option 3: Introduce a generic profile flag or subcommand parser

Pros:
- cleaner abstraction long-term

Cons:
- larger refactor than needed right now
- more risk while the goal is simply to get a 4 KB guest running

Recommended: Option 2.

## Approved Design

### Runtime split

Keep the existing 16 KB path unchanged and add a second runtime profile with:

- image: `docker.io/redroid/redroid:16.0.0_64only-latest`
- container: `redroid4k-root-safe`
- data volume: `redroid4k-data-root`
- ADB endpoint: `127.0.0.1:5556`
- VNC endpoint: `127.0.0.1:5901`

This keeps the data volume and container identity separate from the current 16 KB baseline while avoiding a deeper script rewrite.

### Operator actions

Add explicit 4 KB actions:

- `restart-4k`
- `status-4k`
- `verify-4k`
- `viewer-4k`

These should reuse the same container creation, permission repair, ADB wait, and viewer sync logic, but run with the 4 KB runtime profile.

### Viewer behavior

The current viewer helper is hardcoded to `127.0.0.1:5555`. Update it to read an environment override for the ADB serial so `viewer-4k` can launch it against `127.0.0.1:5556` without duplicating the viewer script.

### Verification

Local verification should prove:

- dry-run output exposes the 4 KB image, container, ports, and volume
- the original 16 KB dry-run still points at the existing 16 KB values
- the viewer helper can accept an alternate ADB serial

Live verification should prove:

- `restart-4k` boots the 4 KB guest
- `verify-4k` reaches ADB and reports the alternate runtime shape
- Android inside the 4 KB guest responds on the alternate ADB port

## Next Step

Write a narrow implementation plan, then add the tests before touching the script or viewer helper.
