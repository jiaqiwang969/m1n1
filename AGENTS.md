# Project Direction

This workspace has one default mainline:

- `16K` Asahi Linux host
- `4K` microVM guest
- Redroid inside the `4K` guest
- Douyin running inside that guest

This path is called `Guest4K`.

## Default Assumption

Unless the user explicitly says otherwise, all analysis, fixes, scripts, docs, and experiments
should serve the `Guest4K` mainline.

## What Counts As In Scope

By default, work should improve one of these:

- `Guest4K` boot reliability
- `Guest4K` graphics stability
- `Guest4K` audio quality
- `Guest4K` viewer and interaction quality
- Douyin usability inside `Guest4K`
- `Guest4K` operator workflows
- `Guest4K` documentation clarity

## What Is Not The Default Direction

The older direct-host Redroid path is not the default direction.

Treat it as:

- frozen history
- reference material
- experiment-only work when the user explicitly asks for it

Do not drift into direct-host host-mode root-fix work unless the user clearly requests that branch.

## Safety Rule

Protect the currently working `Guest4K` path on `192.168.1.107`.

Prefer:

- read-only inspection first
- scratch files and staging dirs
- reversible changes
- one narrow change at a time

Avoid broad changes that could destabilize the working mainline without explicit user approval.

## Documentation Rule

When editing docs:

- present `Guest4K` as the mainline first
- describe current mainline problems clearly
- keep direct-host material brief and clearly marked as historical or frozen

## Operator Rule

The default operator entry point is:

- `redroid/scripts/redroid_guest4k_107.sh`

If a change does not help that path directly, question whether it belongs in the current task.
