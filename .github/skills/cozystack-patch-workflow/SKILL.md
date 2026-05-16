---
name: cozystack-patch-workflow
description: 'Workflow skill for creating, validating, and applying patches against an upstream CozyStack source tree. Use when: creating new patches for CozyStack ARM64 image builds; editing Dockerfiles or Makefiles in a cloned CozyStack worktree; running git diff to produce numbered patch files; validating patches with git apply --check; adding patches to the build workflow matrix; reviewing or updating existing patches in patches/. DO NOT use for general Kubernetes troubleshooting or Talos node configuration.'
argument-hint: 'Describe the change you want to patch (e.g. "set default PLATFORM to linux/arm64 in common-envs.mk")'
---

# CozyStack Patch Workflow

## Overview

This skill produces reproducible `.patch` files against a pinned upstream CozyStack
release. Patches are always generated from actual edits to a cloned worktree — never
hand-crafted.

## Invariants

- **No hand-crafted patches.** Every patch is produced via `git diff` on a real edit.
- Patches live in `patches/` with the naming scheme `<NN>-<slug>.patch`.
- Always validate with `git apply --check` on a separate clean clone before committing.
- The upstream ref to patch against is `v1.3.3` unless a newer pinned version is active.

## Workflow

### 1. Prepare a patch worktree

```bash
UPSTREAM_REF=v1.3.3
WORKDIR=/tmp/cozy-patch-work
git clone --depth 1 --branch "$UPSTREAM_REF" \
  https://github.com/cozystack/cozystack "$WORKDIR"
```

### 2. Make the targeted edit

Edit the file(s) inside `$WORKDIR`. Keep changes minimal and focused. Document *why*
in the commit message or a comment if the diff doesn't make it obvious.

Common edit targets for ARM64 work:
- `hack/common-envs.mk` — default `PLATFORM`
- `packages/system/<pkg>/Makefile` — platform flags, skopeo retag logic
- `packages/system/<pkg>/images/<name>/Dockerfile` — base image arch

### 3. Produce the patch

```bash
cd "$WORKDIR"
NEXT_NUM=$(ls /path/to/repo/patches/*.patch 2>/dev/null | wc -l | tr -d ' ')
PADDED=$(printf "%02d" $((NEXT_NUM + 1)))
git diff > /path/to/repo/patches/${PADDED}-<slug>.patch
```

### 4. Validate on a clean clone

```bash
VALIDATE_DIR=/tmp/cozy-validate-$$
git clone --depth 1 --branch "$UPSTREAM_REF" \
  https://github.com/cozystack/cozystack "$VALIDATE_DIR"
git -C "$VALIDATE_DIR" apply --check \
  /path/to/repo/patches/${PADDED}-<slug>.patch
echo "Patch check exit code: $?"
```

A zero exit code means the patch applies cleanly.

### 5. Register the patch in the build workflow

In `.github/workflows/build-talos-images.yml` (or the relevant workflow), find the
`Apply patches` step and add the new patch:

```yaml
- name: Apply patches
  run: |
    git apply patches/01-arm64-spin-tailscale.patch
    git apply patches/02-makefile-architecture-variables.patch
    git apply patches/03-arm64-spin-only.patch
    git apply patches/${PADDED}-<slug>.patch   # ← add here
```

### 6. Commit

```bash
git add patches/${PADDED}-<slug>.patch
git add .github/workflows/build-talos-images.yml   # if workflow changed
git commit -m "patches: add ${PADDED}-<slug> — <one line description>"
```

## Patch Naming Conventions

| Number | Purpose |
|--------|---------|
| 01–03 | Talos ARM64 profile + extension variants (existing) |
| 04 | `hack/common-envs.mk` — default PLATFORM=linux/arm64 |
| 05 | `packages/system/dashboard/Makefile` — add arm64 to hardcoded platform |
| 06 | `packages/system/kubeovn/Makefile` — retag full manifest list |
| 07+ | Future package-specific ARM64 fixes |

## Troubleshooting

**`git apply --check` fails with "patch does not apply"**
The upstream file changed between the patch source and the validation clone. Re-diff
against the exact same `UPSTREAM_REF` tag, or rebase the edit onto the newer ref.

**Makefile variable not being picked up**
Check `hack/common-envs.mk` include order. Variables set before the `include` line
will not be overridden by the `?=` default.

**Skopeo retag copies only amd64 manifest**
Use `skopeo copy --all` (or `crane copy`) to copy the full manifest list. Omitting
`--all` causes skopeo to resolve the manifest to the host arch and copy only that
single-arch manifest.

## References

- Upstream CozyStack: https://github.com/cozystack/cozystack
- Build workflows: [.github/workflows/](.github/workflows/)
- Existing patches: [patches/](patches/)
- JUNIPER-8 plan: [docs/JUNIPER-8-ARM64-COZYSTACK-IMAGES.md](docs/JUNIPER-8-ARM64-COZYSTACK-IMAGES.md)
