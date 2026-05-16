# JUNIPER-8: ARM64 CozyStack Image Rebuild

**Date: 2026-05-15**

## Mission

Build all CozyStack v1.3.3 in-tree images for `linux/arm64` and ship them to
`ghcr.io/urmanac/cozystack-assets/*`, so that a real ARM64 cluster (CM4 / Turing Pi)
can run the full CozyStack stack without `exec format error` crashes.

## Context

ION-7 audit found that every image CozyStack builds in-tree is amd64-only. The root
cause is `hack/common-envs.mk` leaving `PLATFORM ?=` empty, so builds on GitHub's
amd64 runners always produce single-arch amd64 images.

The `kubeovn` image is additionally broken because the retag step copies only the amd64
manifest to GHCR, pinning a `@sha256:...` digest that points to the amd64 manifest.

Cilium was already fixed by pinning to `quay.io/cilium/cilium:v1.19.4` (upstream
multi-arch) in the active HelmRelease.

## Target Registry Layout

All arm64 images ship to `ghcr.io/urmanac/cozystack-assets/cozystack/<name>:<tag>`,
mirroring the upstream `ghcr.io/cozystack/cozystack/<name>:<tag>` path structure so
overrides are easy to express as a single registry swap.

## Patch Strategy

**Rule: no hand-crafted patches.** Every patch is produced by:
1. `git clone --depth 1 --branch v1.3.3 https://github.com/cozystack/cozystack /tmp/cozy-patch-work`
2. Edit the target file(s) in the worktree.
3. `git diff > patches/<NN>-<description>.patch`
4. Verify with `git apply --check patches/<NN>-<description>.patch` on a clean clone.

## Patches Needed

### Patch 04 — `hack/common-envs.mk`: default PLATFORM to linux/arm64

**File:** `hack/common-envs.mk`

Change:
```makefile
PLATFORM ?=
```
to:
```makefile
PLATFORM ?= linux/arm64
```

This makes `$(BUILDX_ARGS)` inject `--platform=linux/arm64` for every package that
uses `common-envs.mk`, which covers all custom-built images except `dashboard`.

### Patch 05 — `packages/system/dashboard/Makefile`: add arm64 to hardcoded platform

**File:** `packages/system/dashboard/Makefile`

Change every:
```makefile
--platform=linux/amd64 \
```
to:
```makefile
--platform=linux/amd64,linux/arm64 \
```

**Note:** dashboard images are UI-only and not required for cluster operation. This
patch can be deferred if the cross-compile adds build time we can't absorb.

### Patch 06 — `packages/system/kubeovn/Makefile`: retag the full manifest list

**File:** `packages/system/kubeovn/Makefile`

The `make update` step currently runs `skopeo copy` (or equivalent) referencing only the
amd64 manifest. We need to copy the full manifest list from `docker.io/kubeovn/kube-ovn`
to our registry, then update `values.yaml` to point at the new location without a
digest pin.

After the copy:
```yaml
global:
  registry:
    address: ghcr.io/urmanac/cozystack-assets/cozystack
  images:
    kubeovn:
      repository: kubeovn
      tag: v1.15.10   # no @sha256 — manifest list selects arch automatically
```

### Patch 07 — `packages/core/talos/Makefile`: arm64 asset names

Already covered by existing patches 01–03 for the Talos/matchbox images in this repo.
No additional patch needed here for the CozyStack-side images.

## Build Workflow Changes

The existing `build-talos-images.yml` builds Talos + matchbox + cozystack-operator.
A new or extended workflow will build the remaining CozyStack packages for arm64:

```
build-cozystack-arm64-images.yml
  matrix:
    package:
      - packages/system/cilium          # already fixed via upstream pin
      - packages/system/kubeovn         # retag manifest list
      - packages/system/metallb
      - packages/system/kamaji
      - packages/system/multus
      - packages/system/kubeovn-webhook
      - packages/system/kubeovn-plunger
      - packages/system/cozystack-controller
      - packages/system/cozystack-api
      - packages/system/backup-controller
      - packages/system/backupstrategy-controller
      - packages/system/lineage-controller-webhook
      - packages/system/linstor
      - packages/system/linstor-gui
  steps:
    - checkout cozystack v1.3.3
    - apply patches 04+
    - for each package: make image REGISTRY=ghcr.io/urmanac/cozystack-assets/cozystack PUSH=true
```

## Override Mechanism

Rather than modifying the upstream Helm charts, overrides are expressed as
`HelmRelease` `.spec.values` patches in the `talm-chart/` (or a new `patches/`
directory):

```yaml
# Example: kubeovn override
kube-ovn:
  global:
    registry:
      address: ghcr.io/urmanac/cozystack-assets/cozystack
    images:
      kubeovn:
        repository: kubeovn
        tag: v1.15.10
```

This approach keeps the CozyStack Helm chart untouched and localises all ARM64
adaptations to this repo.

## Execution Order

1. **Patches 04 + 06** (common-envs default platform, kubeovn manifest-list retag) — these have the highest cluster impact.
2. Produce patch files from cloned worktree via `git diff`.
3. Validate all patches with `git apply --check` on a fresh v1.3.3 clone.
4. Wire patches into the build workflow.
5. Delete stale GHCR tags (`talos:v1.3.3`, `talos:v1.13.2`, `matchbox:talos-v1.13.2-cozy-v1.3.3`).
6. Push `docs/arm64-pxe-guide-refresh` → PR → merge to main.
7. Tag `v1.3.3` on new commit → `release-talos-assets.yml` fires.
8. Inspect published manifests for arm64 presence.
9. Apply kubeovn HelmRelease override on running cluster, watch init containers recover.

## Agent Skill: cozystack-patch-workflow

After this session's patches are validated, we will build a reusable agent skill
(`cozystack-patch-workflow`) that codifies:
- Cloning a specific upstream ref to a temp worktree.
- Making targeted edits.
- Producing a numbered patch file via `git diff`.
- Validating with `git apply --check` on a clean clone.
- Updating the build workflow matrix with the new patch.

This skill lives alongside the existing skills and can be invoked for any future
patch work against CozyStack or similar upstream sources.

## Success Criteria

- `crane manifest ghcr.io/urmanac/cozystack-assets/cozystack/kubeovn:v1.15.10`
  → manifest list with `linux/arm64` entry
- `crane manifest ghcr.io/urmanac/cozystack-assets/cozystack/cozystack-operator:<tag>`
  → contains `linux/arm64`
- kube-ovn init containers reach `Running` on CM4 nodes
- `cozystack-operator` pod runs on arm64 nodes without `exec format error`
