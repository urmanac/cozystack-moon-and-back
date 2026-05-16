Built: 2026-05-16 11:28:29 UTC

- Talos version: `v1.12.7`
- CozyStack release: `v1.3.3`
- Build target: `upstream-images`
- Extracted asset count: `2`

## Asset Digests

| Asset | Digest |
|-------|--------|
| Kernel | `not available` |
| Boot Loader | `not available` |

## What This Build Contains

This page reflects the latest successful main branch build.

When build target is `upstream-images`:
- OCI images are published to GHCR.
- Bootable raw disk assets are not exported in this job.
- Kernel/boot-loader digests may be shown as `not available`.

This release is broader than the earlier Talos-only image flow:

- the release workflow now builds and publishes the in-tree CozyStack image set
	for arm64 before the release artifacts are packaged
- the operator image now carries the rewritten chart bundle that points at our
	registry-backed OCI artifacts
- `v1.3.3` release tags are expected to refresh the full package bundle, not
	just Talos installer/matchbox/operator

If a future release only updates Talos assets, this page should say so
explicitly; otherwise assume the release includes the full package set.

Flashable raw disk images for Raspberry Pi CM4 are published from tagged releases.

Tagged release artifacts:
- `metal-arm64.raw.xz`: flashable bare-metal image for SD/eMMC/NVMe.
- `nocloud-arm64.raw.xz`: image intended for VM/cloud NoCloud metadata workflows.

## Container Images

Spin + Tailscale variant:

```bash
docker pull ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/talos:latest
docker pull ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/matchbox:latest
```

Spin-only variant:

```bash
docker pull ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/talos:latest
docker pull ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/matchbox:latest
```

CozyStack operator:

```bash
docker pull ghcr.io/urmanac/cozystack-assets/cozystack-operator:latest
```

## Extract Assets From OCI

You can extract files from the Talos image tar layer if needed:

```bash
mkdir -p ./cozystack-assets
docker create --name temp-extract ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/talos:latest
docker cp temp-extract:/. ./cozystack-assets
docker rm temp-extract
```

## Repo-Local Validation Before Hardware

When the arm64 hardware lab is unavailable, the following checks are the most
useful things we can do entirely inside this repo:

1. `git apply --check` all patches on a clean upstream `v1.3.3` clone.
2. `make -n build` on a clean upstream clone to verify the package ordering and
	confirm the skipped amd64-only entries are absent.
3. Audit each remaining `images/**/Dockerfile` for hardcoded `linux/amd64`,
	`x86_64`, or architecture-specific download URLs.
4. Exercise single-package builds that are known to be cheap and deterministic,
	especially `packages/system/kubeovn`, `packages/system/cilium`, and the
	operator package in `packages/core/installer`.
5. Verify release-tool dependencies used by the build (`crane`, `helm`, `yq`,
	`flux`) install and resolve on the runner architecture we are targeting.

For the next hardware cycle, the useful external validation target is a native
arm64 AWS Graviton environment. That is a better fit than creating a new AMI:
use the upstream Talos AMI, boot it, then upgrade and install CozyStack on top of
that known-good Talos base.
