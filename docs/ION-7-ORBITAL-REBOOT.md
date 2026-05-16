# ION-7: Orbital Reboot (0.38 -> 1.3.3)

Date: 2026-05-15

## Mission
Revive the ARM64 image pipeline for CozyStack using a modern stable upstream release, while preserving the two-extension-variant deployment model needed for real Raspberry Pi cluster operation.

## What Changed Since 0.38 (Critical Findings)
1. Upstream architecture changed significantly between the 0.38 series and 1.3.x.
2. Talos image build logic moved from packages/core/installer to packages/core/talos.
3. packages/core/installer now builds and publishes cozystack-operator (not Talos assets).
4. Existing patches in this repo were targeting removed paths in packages/core/installer/hack and therefore failed with:
   - gen-profiles.sh: No such file or directory
   - gen-versions.sh: No such file or directory
5. Upstream now has stable release lines (for example release-1.2 and release-1.3), so pinning to a stable tag is preferable to following main for reproducible rebuilds.

## Verified Upstream Baseline
1. Selected baseline: v1.3.3 (stable, non-prerelease).
2. Upstream tag exists and resolves correctly.
3. Clean validation worktree used for patch checks: /tmp/cozystack-v1.3.3-check.

## Project Decisions Confirmed
1. Keep both Talos extension variants:
- spin-only for most nodes.
- spin-tailscale for the dedicated subnet-router node.
2. Pin workflow default to v1.3.3.
3. Include cozystack-operator image publishing in this repo's build bundle.
4. Use ARM64 matchbox base image tag: v0.11.0-310-g77aedbd0-arm64.
5. Follow patch policy strictly: generate patches from edited source with git diff, never hand-edit patch files in place.

## Concrete Repo Updates Applied
1. Workflow updated in [.github/workflows/build-talos-images.yml](.github/workflows/build-talos-images.yml):
- Default ref input now v1.3.3.
- Added build target option image-operator.
- Changed references from installer/hack scripts to talos/hack scripts.
- Talos build section now operates under packages/core/talos.
- Operator image build integrated via packages/core/installer image-operator target.
- ARM64 validation now includes operator image existence and architecture checks.
2. Patch paths aligned to v1.3.3 Talos layout:
- [patches/01-arm64-spin-tailscale.patch](patches/01-arm64-spin-tailscale.patch)
- [patches/02-makefile-architecture-variables.patch](patches/02-makefile-architecture-variables.patch)
- [patches/03-arm64-spin-only.patch](patches/03-arm64-spin-only.patch)
3. Validation helper scripts updated for moved paths:
- [validate-patch.sh](validate-patch.sh)
- [validate-complete.sh](validate-complete.sh)

## Patch Validation Status
Validated against clean upstream v1.3.3 worktree:
1. 01-arm64-spin-tailscale.patch: PASS (git apply --check).
2. 02-makefile-architecture-variables.patch: PASS (git apply --check).
3. 03-arm64-spin-only.patch: PASS (git apply --check).

## Functional Impact of the New Patch Set
1. Talos profile generation switches architecture from amd64 to arm64.
2. Talos profile generation injects Spin (and optionally Tailscale) extension image references.
3. Talos build targets use arm64 asset names in Makefile and matchbox Dockerfile copies.
4. Matchbox image base updated to a recent ARM64-capable upstream tag.
5. Workflow builds operator image as part of the modern CozyStack packaging model.

## Remaining Work Before Merge/Push
1. Run the updated GitHub Actions workflow once for each variant and inspect pushed image manifests:
- spin-only
- spin-tailscale
2. Confirm published operator image coordinates and tags match intended consumption paths.
3. Validate end-to-end CM4 bootstrap path with spin-only first, then enable tailscale variant on one node.
4. Optionally clean old documentation references still pointing to legacy installer/hack locations.

## Why This Matters for CM4 Bring-Up
1. The old 0.38 assumptions no longer represent upstream build topology.
2. Without this migration, ARM64 patching fails before any build starts.
3. With these updates, the repo again aligns with its core purpose: producing publishable ARM64 CozyStack images for real hardware clusters.

---

## ARM64 Image Audit: In-Tree Built Images (CozyStack v1.3.3)

**Finding date: 2026-05-15**

### Root Cause
`hack/common-envs.mk` sets `PLATFORM ?=` (empty). On GitHub's amd64 runners, every `docker buildx build $(BUILDX_ARGS)` produces a single-arch amd64 image. CozyStack v1.3.3 ships **zero** multi-arch images.

The one exception — `packages/system/dashboard` — is irrecoverably amd64-only because its three `docker buildx build` invocations hardcode `--platform=linux/amd64`.

### Packages with In-Tree Built Images (all amd64-only)

| Image | Package | Values key to override |
|---|---|---|
| `cozystack-operator:<TAG>` | `packages/core/installer` | `.cozystackOperator.image` |
| `cozystack-controller:<TAG>` | `packages/system/cozystack-controller` | `.cozystackController.image` |
| `cozystack-api:<TAG>` | `packages/system/cozystack-api` | `.cozystackAPI.image` |
| `backup-controller:<TAG>` | `packages/system/backup-controller` | `.backupController.image` |
| `backupstrategy-controller:<TAG>` | `packages/system/backupstrategy-controller` | `.backupStrategyController.image` |
| `lineage-controller-webhook:<TAG>` | `packages/system/lineage-controller-webhook` | `.lineageControllerWebhook.image` |
| `platform-migrations:<TAG>` | `packages/core/platform` | `.migrations.image` |
| `kamaji:<TAG>` | `packages/system/kamaji` | `.kamaji.image.repository` + `.kamaji.image.tag` |
| `cilium:<appVersion>` | `packages/system/cilium` | `.cilium.image.repository/tag/digest` |
| `kubeovn-webhook:<TAG>` | `packages/system/kubeovn-webhook` | `.image` |
| `kubeovn-plunger:<TAG>` | `packages/system/kubeovn-plunger` | `.image` |
| `matchbox:<TAG>` | `packages/core/talos` | `packages/extra/bootbox/images/matchbox.tag` |
| `metallb-controller/speaker:<ver>` | `packages/system/metallb` | `.metallb.controller/speaker.image.repository/tag` |
| `multus-cni:<TAG>` | `packages/system/multus` | Injected via `sed` in templates |
| `linstor`/`piraeus-server` | `packages/system/linstor` | `.piraeusServer.image.*` |
| `linstor-csi:<ver>` | `packages/system/linstor` | `.linstorCSI.image.*` |
| `linstor-gui:<ver>` | `packages/system/linstor-gui` | `.image.*` |
| `openapi-ui` + 2 others | `packages/system/dashboard` | **amd64 hardcoded — skip** |
| `grafana-dashboards:<TAG>` | `packages/system/grafana-operator` | `.tag` file |

### kubeovn: amd64-only retag confirmed

```
ghcr.io/cozystack/cozystack/kubeovn:v1.15.10
→ manifest.v2+json (single-arch, amd64 only)
```

Upstream `docker.io/kubeovn/kube-ovn:v1.15.10` is a proper manifest list:
- `arm64` → `sha256:a64ff020a2f2a89ff2494565941e584029aee19f49d9a1fd631dbfcbdd0efbca`
- `amd64` → `sha256:8cc2afda38aa9cd400cab1d30f5833ec3839e30acd2d46898f49e8f9510f349a`

CozyStack's `make update` retags only the amd64 manifest to GHCR — it never copies the full manifest list.

### kube-ovn values.yaml pin (the actual breakage)

```yaml
global:
  registry:
    address: ghcr.io/cozystack/cozystack
  images:
    kubeovn:
      repository: kubeovn
      tag: v1.15.10@sha256:741299cbd0081a786a6b60c460fa3156b3a42a38141c559dd8ac031f50c5504f
```

The `@sha256:...` digest pins to the amd64 manifest specifically. On arm64 nodes the pod fails with `exec format error`.

### Packages that pull upstream multi-arch (no rebuild needed)

`cert-manager`, `fluxcd`, `metrics-server`, `ingress-nginx`, `coredns`, `cloudnative-pg` (postgres-operator), `external-secrets`, `keycloak`, `piraeus-operator`, `victoria-metrics-operator`, `snapshot-controller`.

### kubevirt: special status

`quay.io/kubevirt/*` — ARM64 support is experimental upstream. Avoid KubeVirt workloads on pure ARM64 nodes for now.

### Plan for JUNIPER-8

1. Clone upstream CozyStack v1.3.3, make `PLATFORM=linux/arm64` changes, run `git diff` to produce new patches (never hand-craft patches).
2. Build all critical in-tree images for `linux/arm64`, pushing to `ghcr.io/urmanac/cozystack-assets/*`.
3. The `kubeovn` image specifically: retag the upstream arm64 manifest to our registry rather than retagging a single-arch amd64 manifest.
4. Override image refs in `talm-chart/` or via `HelmRelease` patches to point at `ghcr.io/urmanac/cozystack-assets/*` ARM64 images.
5. Delete stale tags, push PR to `docs/arm64-pxe-guide-refresh` → main → tag → CI publishes new bundle.

---

## Release tag drift bug (found 2026-05-15)

### Symptom

After tagging `v1.3.3` and watching the release workflow succeed, the GHCR UI showed:

- `matchbox:talos-v1.12.7-cozy-v1.3.3` — published 5 minutes ago, digest X
- `matchbox:latest` — published 6 months ago, **same digest X**

This was suspicious: a fresh release tag was aliased to whatever `:latest`
happened to point to, *not* to a freshly built image.

### Root cause

[release-talos-assets.yml](.github/workflows/release-talos-assets.yml)
retagged in the wrong direction:

```bash
# BEFORE (broken):
crane tag matchbox:latest         talos-v1.12.7-cozy-v1.3.3
crane tag cozystack-operator:latest  v1.3.3
```

`:latest` is mutable — it can be updated by any prior workflow run (or stay
stale if no recent build pushed). Reading *from* `:latest` means the release
composite tag inherits whatever `:latest` happens to be pointing at when the
release fires, with no guarantee the bits are the ones built in this release
cycle.

### Fix

Always retag *from* an immutable canonical tag:

- matchbox: `:${TALOS_VERSION}-${RELEASE_TAG}` (e.g. `v1.12.7-v1.3.3`),
  produced by upstream Makefile when cozystack-upstream HEAD is at the
  `v1.3.3` git tag (`docker buildx --tag matchbox:$(TALOS_VERSION)-$(TAG)`).
- operator: `:${RELEASE_TAG}` (e.g. `v1.3.3`), produced by
  `make image-operator` against cozystack `v1.3.3`.

Then alias `:latest` *from* the canonical tag, so `:latest` always reflects
the most recently released bits.

```bash
# AFTER (correct):
SRC=matchbox:v1.12.7-v1.3.3                # immutable, built this cycle
crane tag "$SRC" talos-v1.12.7-cozy-v1.3.3 # composite
crane tag "$SRC" latest                    # alias to fresh canonical

SRC=cozystack-operator:v1.3.3              # immutable, built this cycle
crane tag "$SRC" latest                    # alias to fresh canonical
```

### Why the symptom matched the released bits anyway

In this specific run the upstream `:latest` happened to already be the
correct digest because `build-talos-images.yml` had just run on the merge
to main and pushed `:latest` *and* `:v1.12.7-v1.3.3` to the same digest.
The release tag therefore aliased the right content — but only by
coincidence. The fix removes the coincidence.
