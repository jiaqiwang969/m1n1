# Redroid Guest4K Runtime Design

## Context

The repository already has a stable direct-host Redroid path for the 16 KB Asahi machine, but the previous `restart-4k` workflow was based on the wrong assumption that a true 4 KB Redroid runtime could be created directly on the same 16 KB host.

Live debugging changed that conclusion.

What is now proven:

- host: Fedora Asahi Remix on `192.168.1.107`
- host kernel page size: `16384`
- guest: Ubuntu microVM at `/home/wjq/vm4k/ubuntu24k`
- guest page size: `4096`
- VM forwarding: host `127.0.0.1:2222 -> guest:22`, `127.0.0.1:5556 -> guest:5555`, `127.0.0.1:5901 -> guest:5900`
- bad path: Redroid inside the guest with `--network host`
- good path: Redroid inside the guest with isolated container networking plus explicit `-p 5555:5555` and `-p 5900:5900`

The decisive live proof was:

- with `--network host`, new SSH, ADB, and VNC connections degraded after Redroid started
- `passt` still accepted host-side sockets and forwarded guest-bound SYN packets
- guest-side SYN-ACKs did not come back
- replacing `--network host` with isolated container networking restored:
  - guest SSH stability on host `127.0.0.1:2222`
  - ADB on host `127.0.0.1:5556`
  - VNC banner on host `127.0.0.1:5901`

That means the stable 4 KB route is not "direct host 4k". It is:

`16K Asahi host -> 4K microVM guest -> Redroid container with isolated container network`

## Goal

Add a dedicated operator surface for the proven Guest4K runtime so the repository can:

- start and stop the 4 KB microVM
- launch Redroid inside the guest with the known-good network shape
- verify ADB and VNC from the host side
- keep the Guest4K workflow separate from the direct-host 16K workflow
- document the architectural reason why Guest4K is now the recommended path for further Douyin work

## Options Considered

### Option 1: Keep extending `redroid_root_safe_107.sh`

Pros:

- one command surface
- less file count

Cons:

- mixes two different architectures into one script
- makes the host-vs-guest boundary harder to understand
- keeps the obsolete direct-host `restart-4k` story alive

### Option 2: Add a dedicated `redroid_guest4k_107.sh`

Pros:

- clean separation between direct-host 16K and microVM Guest4K
- easier to document exact host and guest boundaries
- safer to evolve without breaking the current 16K operator flow

Cons:

- one more script to maintain
- some helper logic will be parallel rather than shared

### Option 3: Refactor everything into a generic profile framework

Pros:

- cleaner long term

Cons:

- larger rewrite than needed right now
- slows down the immediate goal of locking in the proven Guest4K path

Recommended: Option 2.

## Approved Design

### Operator boundary

Keep the current script for the direct-host 16K route:

- `redroid/scripts/redroid_root_safe_107.sh`

Add a new dedicated Guest4K operator:

- `redroid/scripts/redroid_guest4k_107.sh`

The new script owns:

- host VM lifecycle
- host-to-guest SSH access
- guest Redroid lifecycle
- Guest4K verification and viewer entry points

### Remote topology

The new script should treat the topology explicitly:

- host SSH target: `wjq@192.168.1.107`
- VM directory on host: `/home/wjq/vm4k/ubuntu24k`
- guest SSH key on host: `/home/wjq/vm4k/ubuntu24k/guest_key`
- guest SSH endpoint from host: `127.0.0.1:2222`
- guest Redroid ADB endpoint from host: `127.0.0.1:5556`
- guest Redroid VNC endpoint from host: `127.0.0.1:5901`

### Guest Redroid command shape

The new script should pin the proven runtime shape inside the guest:

- image: `localhost/redroid16k-root:latest`
- container: `redroid16kguestprobe`
- volume: `redroid16kguestprobe-data`
- `--privileged`
- no `--network host`
- explicit port publishing:
  - `-p 5555:5555/tcp`
  - `-p 5900:5900/tcp`
- binderfs mapped from the guest host
- `/dev/dri` mapped into the guest container
- `/init` entrypoint

### User-facing actions

The Guest4K script should expose a small explicit surface:

- `vm-start`
- `vm-stop`
- `vm-status`
- `restart`
- `status`
- `verify`
- `viewer`

Meaning:

- `vm-*` controls only the microVM
- `restart` controls the Redroid container inside the guest
- `status` shows VM plus guest/container state
- `verify` proves ADB/VNC/boot state from the host-visible endpoints
- `viewer` launches the existing viewer helper against `127.0.0.1:5556`

### Verification

Local verification should prove:

- dry-run output includes the VM directory and guest key path
- dry-run output shows guest-side `podman run` with published ports, not `--network host`
- dry-run output shows host-visible ADB endpoint `127.0.0.1:5556`
- dry-run output shows host-visible VNC endpoint `127.0.0.1:5901`

Live verification should prove:

- the VM starts cleanly
- guest SSH remains stable after Redroid starts
- `adb connect 127.0.0.1:5556` returns `device`
- VNC port `5901` returns an `RFB` banner

## Next Step

Write the implementation plan, then add tests for the new Guest4K operator before implementing the script.
