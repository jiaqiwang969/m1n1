# Guest4K Make Dev Design

## Goal

Add one obvious operator entrypoint so the working mainline can be opened with:

```bash
SUDO_PASS='...' make dev
```

The result should be the current mainline shape:

- `16K` Asahi host
- `4K` microVM guest
- Redroid inside the guest
- TigerVNC viewer on the host
- Douyin launched inside the guest

## Constraints

- Do not create a second orchestration path.
- Reuse `redroid/scripts/redroid_guest4k_107.sh` as the single source of runtime behavior.
- Keep the feature thin and reversible.
- Preserve environment-variable overrides such as `SUDO_PASS`, `REDROID_HOST`, `VIEWER_MODE`,
  and audio tuning knobs.

## Recommended Approach

Add a small set of `Makefile` targets that delegate to the existing Guest4K script:

- `make dev-up`
- `make dev-verify`
- `make dev-view`
- `make dev-douyin`
- `make dev`

`make dev` should execute the already-proven sequence:

1. `vm-start`
2. `restart-preserve-data`
3. `verify`
4. `viewer`
5. `douyin-start`

## Why This Approach

This keeps the operator entrypoint short without duplicating shell orchestration logic.
`Makefile` becomes a convenience layer only; the Guest4K script remains the canonical runtime
surface.

## Testing Strategy

Add tests that run `make -n` and verify:

- the new targets exist
- the correct Guest4K script is used
- `make dev` expands into the expected ordered sequence
- `make dev-up` uses `restart-preserve-data`, not destructive `restart`

## Documentation Impact

Update `README.md` so future operators see `make dev` as the default one-command bootstrap for the
working mainline.
