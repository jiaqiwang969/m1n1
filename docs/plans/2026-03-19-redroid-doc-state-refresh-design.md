# Redroid Doc State Refresh Design

## Context

The repository documentation drifted behind the latest live Douyin repro state.

`README.md` and `docs/guides/install-china-apps.md` still describe patched `libtnet-3.1.14.so` on `#UPush-1` / `JNI_OnLoad` as the current first native blocker. That was true for earlier controlled repros, but the newest baseline saved under `tmp/live/20260319-134419-douyin-surfacecontrol-surfaceview-1-current-base/` shows a later state:

- `pageSizeCompat=36` is still active
- launch reaches `com.ss.android.ugc.aweme/.main.MainActivity`
- the process is gone by the 10s check and launcher is resumed
- `libttmverify.so` still fails to resolve `Cronet_CertVerify_DoVerify`, then Douyin falls back to `libttmverifylite.so`
- the first fatal crash is `SIGSEGV` on thread `VOutle2-V1`
- the backtrace frames are in `libttmplayer.so`

A follow-up single-variable experiment in the same directory changed only `player_enable_surfacecontrol_surfaceview=1`, moved the live `sgv` hash from `4d06f00da45dd71a839b58d9187dc2d489a57efaecd9936b864e7c5243f9fd4d` to `7ff4ab556081a04c8d04ae5062381bb4a1ea7a3de6b60f38281e14b84e74574c`, and still reproduced the same `VOutle2-V1` / `libttmplayer.so` crash. The original hash was then restored.

## Goals

- Refresh the top-level project summary so it matches the latest verified live state.
- Refresh the China-app installation guide so the current first blocker is documented accurately.
- Preserve the `libtnet` workflow documentation, but reframe it as forensic / historical tooling rather than the current first blocker claim.
- Avoid repository reorganization or script changes in this pass.

## Non-Goals

- No new remote experiments.
- No operator-script edits.
- No file moves or workspace layout changes.
- No attempt to solve `libttmplayer.so` yet.

## Approved Design

### README scope

Update the current-status bullets, the Douyin lessons section, and the "Next Phase" list so they describe:

- current live baseline hash `4d06...`
- `pageSizeCompat=36`
- launch reaching `MainActivity`
- fallback from `libttmverify.so` to `libttmverifylite.so`
- first fatal crash now being `VOutle2-V1` / `libttmplayer.so`
- `player_enable_surfacecontrol_surfaceview=1` being disproven as a fix

Keep the `douyin-libtnet-*` workflow documented, but explicitly describe it as baseline control / verification tooling.

### Guide scope

Update the high-level conclusion, the recommended next direction, the `libtnet` workflow explanation, the latest-live-validation section, and the unresolved-issues section so they no longer claim that patched `libtnet` / `JNI_OnLoad` is the newest live blocker.

The guide should instead say:

- the package-manager gate is already passed
- the live baseline currently dies later in `libttmplayer.so`
- `player_enable_surfacecontrol_surfaceview=1` did not move the crash
- earlier `libtnet` work still matters as context, but not as the current headline blocker

## Verification Strategy

- Search the edited docs for stale phrases such as "current latest live native blocker is patched `libtnet`" and "`libtnet` remains the current next gate".
- Search the edited docs for the new evidence anchors: `4d06f00d`, `7ff4ab55`, `VOutle2-V1`, `libttmplayer.so`, and `surfacecontrol_surfaceview`.
- Re-open the fresh evidence files and confirm the revised statements match them.
