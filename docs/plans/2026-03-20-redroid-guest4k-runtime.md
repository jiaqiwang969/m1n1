# Redroid Guest4K Runtime Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a dedicated Guest4K operator and documentation surface for the proven `16K host -> 4K microVM -> isolated-network Redroid` runtime.

**Architecture:** Keep the existing direct-host 16K operator untouched for its current role, and add a second script that manages the host VM plus the guest Redroid container as one explicit workflow. Update docs to explain that the old direct-host `restart-4k` idea is obsolete and that Guest4K is the current stable path for further China-app work.

**Tech Stack:** `zsh`, `ssh`, `podman`, `adb`, `python3`, `unittest`, Markdown

---

### Task 1: Add the design and plan docs for Guest4K

**Files:**
- Create: `docs/plans/2026-03-20-redroid-guest4k-runtime-design.md`
- Create: `docs/plans/2026-03-20-redroid-guest4k-runtime.md`

**Step 1: Write the design doc**

Capture the live evidence:

- why direct-host `restart-4k` is the wrong model on a 16 KB host
- why `--network host` inside the guest was the actual breakage
- why isolated container networking is the proven fix

**Step 2: Write the implementation plan**

Describe the new Guest4K operator surface, the exact files to change, and the required verification commands.

**Step 3: Verify the docs exist**

Run: `find docs/plans -maxdepth 1 -type f | sort | grep guest4k`

Expected: both new Guest4K docs appear.

### Task 2: Add failing tests for the Guest4K operator

**Files:**
- Create: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Write the failing tests**

Add tests that assert:

- `--dry-run vm-start` exits `0`
- `--dry-run restart` exits `0`
- dry-run output mentions `/home/wjq/vm4k/ubuntu24k`
- dry-run output mentions `/home/wjq/vm4k/ubuntu24k/guest_key`
- dry-run output mentions `127.0.0.1:5556`
- dry-run output mentions `127.0.0.1:5901`
- dry-run output mentions `podman run -d --name redroid16kguestprobe`
- dry-run output mentions `-p 5555:5555/tcp`
- dry-run output does not mention `--network host`

**Step 2: Run the test to verify failure**

Run: `python3 -m unittest tests/redroid/test_redroid_guest4k_107.py -v`

Expected: FAIL because the Guest4K script does not exist yet.

### Task 3: Implement the Guest4K operator script

**Files:**
- Create: `redroid/scripts/redroid_guest4k_107.sh`

**Step 1: Add host constants and dry-run plumbing**

Include:

- remote host and user
- VM directory
- guest SSH key path
- host-visible ADB and VNC endpoints
- container and volume names

**Step 2: Implement VM actions**

Support:

- `vm-start` via `launch.sh`
- `vm-stop` via `stop.sh`
- `vm-status` via `status.sh`

**Step 3: Implement guest command helpers**

Add helpers that:

- SSH to the host
- SSH from the host into the guest
- run `sudo` inside the guest
- work in dry-run mode without touching the real host

**Step 4: Implement Guest4K Redroid restart**

Inside the guest:

- ensure binderfs is mounted at `/dev/binderfs`
- remove any old Guest4K container and volume
- run the known-good `podman run` command with isolated container networking and published ports

**Step 5: Implement status, verify, and viewer**

`status` should summarize:

- VM state
- guest page size
- guest container status

`verify` should prove:

- host-visible SSH to guest still works
- `adb connect 127.0.0.1:5556`
- Android boot and `vendor.vncserver` state
- VNC banner on `127.0.0.1:5901`

`viewer` should sync and launch the existing viewer helper against `127.0.0.1:5556`.

### Task 4: Update the durable docs

**Files:**
- Modify: `README.md`
- Modify: `docs/guides/install-china-apps.md`

**Step 1: Rewrite the runtime section in the root README**

Document the two distinct baselines:

- direct-host 16K
- Guest4K microVM

State clearly that:

- the old direct-host `restart-4k` story is obsolete for this machine
- the current stable 4 KB route is the Guest4K microVM path

**Step 2: Add the Guest4K command examples**

Include examples for:

- `vm-start`
- `restart`
- `verify`
- `viewer`

**Step 3: Update the China-app guide**

Make Guest4K the recommended path for the next Douyin runtime experiments.

### Task 5: Run local verification

**Files:**
- Validate: `redroid/scripts/redroid_guest4k_107.sh`
- Validate: `tests/redroid/test_redroid_guest4k_107.py`
- Validate: `README.md`
- Validate: `docs/guides/install-china-apps.md`

**Step 1: Run the Guest4K unit test**

Run: `python3 -m unittest tests/redroid/test_redroid_guest4k_107.py -v`

Expected: PASS.

**Step 2: Dry-run the Guest4K actions**

Run:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh --dry-run vm-start
zsh redroid/scripts/redroid_guest4k_107.sh --dry-run restart
zsh redroid/scripts/redroid_guest4k_107.sh --dry-run verify
```

Expected:

- dry-run output shows the VM path
- dry-run output shows the guest SSH path
- dry-run output shows isolated container networking with `-p 5555:5555/tcp`

### Task 6: Run live verification on the remote host

**Files:**
- Modify: none

**Step 1: Start the VM**

Run:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh vm-start
```

**Step 2: Launch Guest4K Redroid**

Run:

```bash
SUDO_PASS=123123 zsh redroid/scripts/redroid_guest4k_107.sh restart
```

**Step 3: Verify the runtime**

Run:

```bash
zsh redroid/scripts/redroid_guest4k_107.sh verify
```

Expected:

- guest SSH remains reachable on host `127.0.0.1:2222`
- `adb connect 127.0.0.1:5556` reports `device`
- `adb shell getprop sys.boot_completed` returns `1`
- VNC banner is available on `127.0.0.1:5901`
