# Douyin Page-Size Compat Automation Design

## Context

The current Redroid baseline on `192.168.1.107` can install and launch Douyin, but Android 16 blocks first launch with a 16 KB page-size compatibility warning unless the package's stored `pageSizeCompat` value is changed from `4` to `36` in `/data/system/packages.xml`, followed by a container restart.

That workaround is now verified, but it is still manual and easy to regress after reinstalling Douyin or rebuilding the data volume.

## Goal

Add a script-level workflow that:

- checks whether Douyin is installed
- inspects the current `pageSizeCompat` value
- applies the `4 -> 36` patch only when needed
- restarts Redroid so the patched state is actually used
- provides a verification path that reports the current compat state

## Options Considered

### Option 1: Always patch inside `restart`

Pros:
- fully automatic after every restart

Cons:
- requires an extra restart when the patch is first applied
- makes normal restarts slower even when Douyin is not installed
- couples a Douyin-specific workaround to every container lifecycle

### Option 2: Add an explicit `douyin-compat` action to the existing operator script

Pros:
- keeps the workaround discoverable and automated
- only runs when the operator asks for it
- can include its own verification and restart sequence
- avoids slowing every restart

Cons:
- requires one extra operator step after APK install

### Option 3: Keep it manual and document it only

Pros:
- no code changes

Cons:
- easy to forget
- hard to verify consistently
- too much error-prone shell quoting for repeated use

Recommended: Option 2.

## Approved Design

### Script surface

Extend `redroid/scripts/redroid_root_safe_107.sh` with a new action:

- `douyin-compat`

This action will:

1. verify the container exists and ADB is reachable
2. check whether package `com.ss.android.ugc.aweme` is installed
3. inspect `dumpsys package ... | grep pageSizeCompat`
4. if the value is already `36`, report that no change is needed
5. if the value is `4`, patch `/data/system/packages.xml` inside the device using `abx2xml` and `xml2abx`
6. write back using the already-verified rename replacement flow instead of in-place overwrite
7. restart the Redroid container
8. re-run the existing runtime permission repair
9. verify the final value is `36`

### Verification behavior

`verify` should remain generic, but if Douyin is installed it should also print the current `pageSizeCompat` line so the operator can see whether the workaround is active.

### Safety

- If Douyin is not installed, the action should exit cleanly with a clear message.
- If the package state is not `4` or `36`, the script should print the observed value and stop instead of guessing.
- The original `/data/system/packages.xml` should be preserved as a timestamped backup before replacement.

### Testing

The existing unittest should be extended with dry-run assertions that:

- usage text includes `douyin-compat`
- `--dry-run douyin-compat` emits the package check, ABX/XML conversion, rename replacement, and restart sequence

## Next Step

After this lands, the next deeper track is environment shaping: reduce `redroid/qemu/test-keys/su` exposure and evaluate whether login or account workflows start failing on those signals.
