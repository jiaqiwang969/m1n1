# Redroid True 4K Base Design

## Context

The current Guest4K route solved only the Linux-kernel page-size side:

- host Asahi page size: `16384`
- microVM guest page size: `4096`

But the Android image used inside that guest is still the existing Redroid 16 KB product:

- image tag: `localhost/redroid16k-root:latest`
- runtime property: `ro.product.cpu.pagesize.max=16384`
- source product definition: `device/redroid/redroid_arm64_only.mk`

That means the current stack is:

`16K Android image -> running on top of a 4K guest kernel`

The latest root-cause work also removed the old graphics-node explanation:

- inside both the working direct-host container and the failing Guest4K container, `/dev/dri/card0` and `/dev/dri/renderD128` resolve to working `vkms`
- `DRM_CAP_DUMB_BUFFER=1`
- `DRM_IOCTL_MODE_CREATE_DUMB` succeeds

So the project now needs a true 4 KB Android base, not more DRM remapping experiments.

## Goal

Create a real 4 KB Redroid product variant, build it as a separate image, and verify that:

1. the built image self-describes as a 4 KB Android product
2. the image can be imported without disturbing the current 16 KB baseline
3. the Guest4K workflow can launch that image for the next round of runtime validation

The first milestone is not "Douyin works". The first milestone is "we have a real 4 KB Android image".

## Options Considered

### Option 1: Add a dedicated 4 KB Redroid product variant

Pros:

- keeps the current 16 KB baseline untouched
- makes the new product and output path explicit
- lets us compare 16 KB and 4 KB outputs side by side
- keeps rollback simple

Cons:

- one extra product entry to maintain
- a small amount of duplicated product boilerplate

### Option 2: Parameterize the existing `redroid_arm64_only` product

Pros:

- fewer files

Cons:

- higher risk to the current known-good 16 KB path
- harder to tell which build artifacts belong to which page-size mode
- easier to poison caches and operator expectations

### Option 3: Reuse a "page-agnostic" pattern

Pros:

- sounds conceptually elegant

Cons:

- does not solve the actual problem here
- in this tree, the page-agnostic examples still target `16384` as the max supported page size
- does not produce a truly separate 4 KB Android product

Recommended: Option 1.

## Approved Design

### Product strategy

Create a new product variant alongside the current Redroid product:

- existing: `redroid_arm64_only-bp2a-userdebug`
- new: `redroid_arm64_only_4k-bp2a-userdebug`

The new product should reuse the same Redroid arm64-only device stack, but it must not inherit the 16 KB product policy unchanged.

The 4 KB variant should:

- set `PRODUCT_MAX_PAGE_SIZE_SUPPORTED := 4096`
- avoid carrying the current 16 KB-only developer flags forward blindly
- avoid forcing the 16 KB bionic page-size behavior into the 4 KB product
- tolerate prebuilt max-page-size checks during the first bring-up if needed

The key idea is simple:

- same Redroid functional base
- separate product identity
- separate device entry point for BoardConfig resolution
- separate output directory
- separate imported image tag

In practice, that means the 4 KB variant cannot be only a new product makefile if it also sets a new `PRODUCT_DEVICE`. AOSP resolves `TARGET_DEVICE` to a matching `BoardConfig.mk`, so the 4 KB bring-up should include a minimal `device/redroid/redroid_arm64_only_4k/` wrapper that includes the existing arm64-only device definitions.

### Build and image strategy

Do not overwrite the current image:

- keep `localhost/redroid16k-root:latest`

Build and import a new image tag:

- `localhost/redroid4k-root:latest`

The new product should therefore produce output under a separate target-product directory on the build host, and the import on the Asahi side should use separate staging paths where practical.

### Runtime strategy

Do not change the operator contract first.

The existing Guest4K operator already supports overriding the image through `IMAGE=...`, so the first true-4K validation can use:

```bash
IMAGE=localhost/redroid4k-root:latest zsh redroid/scripts/redroid_guest4k_107.sh restart
```

That keeps the local control surface stable while changing only the Android image under test.

### Verification strategy

Verification should happen in three layers.

Layer 1: product-definition verification

- new lunch target resolves
- build variables report `TARGET_MAX_PAGE_SIZE_SUPPORTED=4096`

Layer 2: image verification

- built `system.img` and `vendor.img` exist under the new product output
- imported image contains `ro.product.cpu.pagesize.max=4096`

Layer 3: Guest4K runtime verification

- Guest4K restarts against `localhost/redroid4k-root:latest`
- either Android boots farther than the current mixed-mode path, or it fails with a new, more truthful boundary

### Risk handling

The most likely first blockers are:

- prebuilt ELF max-page-size checks
- page-size assumptions in vendor or Redroid-specific prebuilts
- service bring-up differences once the whole image becomes genuinely 4 KB

Those are acceptable first-round failures. They are downstream of the correct root fix.

## Out Of Scope For This Pass

This pass does not try to:

- make Douyin fully work
- redesign the Guest4K operator
- solve every later graphics or app-level crash
- replace the 16 KB baseline as the default path

## Next Step

Write the implementation plan for:

1. adding the new 4 KB product
2. building and importing the new image
3. launching it through Guest4K without disturbing the current 16 KB baseline
