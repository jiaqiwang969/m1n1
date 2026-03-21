# Guest4K Default Image Alignment Design

## Scope

Align the current Guest4K operator default with the image that has been verified on the real `16K host + 4K guest` runtime:

- `localhost/redroid4k-root:alsa-hal-ranchu-exp2`

This change is intentionally limited to the current operator surface:

- [`redroid/scripts/redroid_guest4k_107.sh`](/Users/jqwang/25-红手指手机/m1n1/redroid/scripts/redroid_guest4k_107.sh)
- [`tests/redroid/test_redroid_guest4k_107.py`](/Users/jqwang/25-红手指手机/m1n1/tests/redroid/test_redroid_guest4k_107.py)
- [`README.md`](/Users/jqwang/25-红手指手机/m1n1/README.md)
- [`docs/guides/install-china-apps.md`](/Users/jqwang/25-红手指手机/m1n1/docs/guides/install-china-apps.md)

Historical `docs/plans/*.md` records stay unchanged.

## Options Considered

### Option A: Promote the verified audio image to the operator default

Change the Guest4K script default image and update the user-facing docs to match.

Pros:

- aligns the repo's executable default with the actually verified runtime
- removes the need for repeated `IMAGE=...` overrides
- lowers operator error rate

Cons:

- older notes that mention previous experimental tags become historical only

### Option B: Keep the old default and require explicit `IMAGE=...`

Pros:

- smaller code change

Cons:

- the default path remains wrong for current use
- easy to regress into the stale image line

### Option C: Add a separate audio-specific script/profile

Pros:

- preserves the old default untouched

Cons:

- adds another entry point and more operational drift

## Decision

Use Option A.

The repository should default to the image that is currently proven on the real target runtime. The older image tags remain documented only as historical context.

## Validation

Validation for this change consists of:

1. script dry-run test updated to the new default image
2. full `tests/redroid/test_redroid_guest4k_107.py` pass
3. real runtime proof that:
   - `restart-preserve-data` succeeds
   - guest `getenforce` is `Permissive`
   - Douyin launches successfully
