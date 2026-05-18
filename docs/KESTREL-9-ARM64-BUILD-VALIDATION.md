# KESTREL-9: ARM64 Build Validation

**Date:** 2026-05-16  
**Context:** PRs #53 (full image rebuild), #55 (skip linstor), #56 (crane flag fix)  
**Purpose:** Pre-merge validation of patches 04 + 06 + 07 before retagging v1.3.3

---

## Motivation

After three failed CI runs (linstor gradle/protoc amd64-binary failure, crane `--all`
flag not existing), we validated everything locally before burning another 20-minute
CI run. This document records what was tested and what was found.

---

## Test 1: Patch chain validates cleanly

All three patches were verified to apply without conflict on a clean v1.3.3 clone:

```bash
git clone --branch v1.3.3 --depth 1 https://github.com/cozystack/cozystack.git cozystack-check
cd cozystack-check
git apply --check patches/04-arm64-default-platform.patch   # PASS
git apply patches/04-arm64-default-platform.patch
git apply --check patches/06-kubeovn-manifest-list-retag.patch  # PASS
git apply patches/06-kubeovn-manifest-list-retag.patch
git apply --check patches/07-arm64-skip-amd64-only-builds.patch  # PASS
# ALL PATCHES VALIDATE
```

Result: **PASS**

---

## Test 2: crane --platform all flag is valid

Confirmed the correct flag for copying a full manifest list (all platforms) before
committing patch 06's fix. The flag `--all` does not exist in crane v0.20.6; the
correct form is `--platform all`.

```bash
crane version
# 0.20.6

crane copy --platform all docker.io/kubeovn/kube-ovn:v1.15.10 \
  ghcr.io/urmanac/cozystack-assets/kubeovn:v1.15.10-test
# 2026/05/16 07:19:12 Copying from docker.io/kubeovn/kube-ovn:v1.15.10 to ghcr.io/...
# (fails on GHCR auth as expected locally — flag was accepted, copy started)
```

Result: **PASS** — flag is valid, copy initiates correctly

---

## Test 3: make build dry-run (make -n)

Verified the exact sequence of packages that will be built, confirming dashboard,
linstor, linstor-gui, and core/talos are absent:

```
make -C packages/apps/http-cache image
make -C packages/apps/mariadb image
make -C packages/apps/clickhouse image
make -C packages/apps/kubernetes image
make -C packages/system/monitoring image
make -C packages/system/cozystack-api image
make -C packages/system/cozystack-controller image
make -C packages/system/backup-controller image
make -C packages/system/backupstrategy-controller image
make -C packages/system/lineage-controller-webhook image
make -C packages/system/cilium image
make -C packages/system/kubeovn image
make -C packages/system/kubeovn-webhook image
make -C packages/system/kubeovn-plunger image
make -C packages/system/metallb image
make -C packages/system/kamaji image
make -C packages/system/multus image
make -C packages/system/bucket image
make -C packages/system/objectstorage-controller image
make -C packages/system/grafana-operator image
make -C packages/core/testing image
make -C packages/core/platform image
make -C packages/core/installer image
```

23 packages. `dashboard`, `linstor`, `linstor-gui`, `core/talos` all absent. ✅

---

## Test 4: Dockerfile audit — all 23 packages

Each package's `images/` directory was inspected for hardcoded architecture
assumptions or binary downloads without arch awareness.

| Package | Dockerfile pattern | arm64 verdict |
|---|---|---|
| `apps/http-cache` | `ARG TARGETARCH` → apk `--pkgarch` | ✅ safe |
| `apps/mariadb` | `FROM alpine:3.20`, apk packages only | ✅ safe |
| `apps/clickhouse` | `FROM clickhouse/clickhouse-server` (multi-arch base) | ✅ safe |
| `apps/kubernetes/kubevirt-csi-driver` | `GOARCH=$TARGETARCH` | ✅ safe |
| `apps/kubernetes/cluster-autoscaler` | `GOARCH=$TARGETARCH`, `COPY ...-${TARGETARCH}` | ✅ safe (comment says `.amd64` but code uses TARGETARCH) |
| `apps/kubernetes/ubuntu-container-disk` | `wget .../noble-server-cloudimg-${TARGETARCH}.img` | ✅ safe |
| `apps/kubernetes/kubevirt-cloud-provider` | `GOARCH=$TARGETARCH` | ✅ safe |
| `system/monitoring` (grafana) | `FROM grafana/grafana:11.4.0` (multi-arch) | ✅ safe |
| `system/cozystack-api` | `GOARCH=$TARGETARCH` | ✅ safe |
| `system/cozystack-controller` | `GOARCH=$TARGETARCH` | ✅ safe |
| `system/backup-controller` | `GOARCH=$TARGETARCH` | ✅ safe |
| `system/backupstrategy-controller` | `GOARCH=$TARGETARCH` | ✅ safe |
| `system/lineage-controller-webhook` | `GOARCH=$TARGETARCH` | ✅ safe |
| `system/cilium` | `docker buildx build` with `$(BUILDX_ARGS)` → `--platform=linux/arm64` via patch 04 | ✅ safe |
| `system/kubeovn` | `crane copy --platform all` (patch 06) | ✅ safe |
| `system/kubeovn-webhook` | `GOARCH=$TARGETARCH` | ✅ safe |
| `system/kubeovn-plunger` | `GOARCH=$TARGETARCH` | ✅ safe |
| `system/metallb` | `FROM quay.io/metallb/{controller,speaker}` (multi-arch) | ✅ safe |
| `system/kamaji` | `GOARCH=$TARGETARCH` | ✅ safe |
| `system/multus` | `FROM --platform=$BUILDPLATFORM golang`, `TARGETPLATFORM` in build script | ✅ safe |
| `system/bucket` (s3manager) | `GOARCH=$TARGETARCH` | ✅ safe |
| `system/objectstorage-controller` | `GOARCH=$TARGETARCH` | ✅ safe |
| `system/grafana-operator` (grafana-dashboards) | `FROM alpine:3.22` + `darkhttpd` — pure alpine | ✅ safe |
| `core/testing` (e2e-sandbox) | `curl .../talosctl-${TARGETOS}-${TARGETARCH}` etc | ✅ safe |
| `core/platform` | no images/ directory; chart-only | ✅ safe |
| `core/installer` (cozystack-operator) | `GOARCH=$TARGETARCH` | ✅ safe |

No hidden amd64 assumptions found in any of the 23 packages.

---

## Known gaps (skipped from build)

| Package | Reason skipped | Patch |
|---|---|---|
| `system/dashboard` | Dockerfile has three `docker buildx build --platform=linux/amd64` calls hardcoded; cannot be rebuilt for arm64 without forking | 07 |
| `system/linstor` | `gradlew getProtoc` downloads `protoc-linux-x86_64` unconditionally; fails with `Syntax error: ")" unexpected` (shell reading amd64 ELF on arm64) | 07 |
| `system/linstor-gui` | depends on linstor | 07 |
| `core/talos` | talos installer + matchbox are variant-specific (spin vs tailscale); built separately in `build-talos-variants` matrix job | 07 |

**Note on linstor:** We have seen linstor run successfully on arm64 hardware in
earlier sessions, so upstream arm64 support does exist — possibly in newer releases
or via a different build path than the in-tree Dockerfile uses here (which builds
from source using gradle). The v1.3.3 CozyStack in-tree Dockerfile for
`packages/system/linstor` pins linstor-server v1.33.2 and downloads
`protoc-31.1-linux-x86_64.tar.gz` unconditionally. Whether a newer version of the
Dockerfile fixes this is worth revisiting in a future patch.

---

## Test 5: flux CLI version and download URL

`core/installer`'s `image-packages` target calls `flux push artifact` to push the
entire CozyStack package tree as an OCI artifact to
`oci://$(REGISTRY)/cozystack-packages:$(TAG)`. This sets
`cozystackOperator.platformSourceUrl` in `values.yaml`, telling the operator where
to fetch chart bundles from at runtime. Without `flux` in `$PATH` the build fails
with `/bin/sh: 1: flux: not found`.

The flux distribution version pinned in `packages/system/fluxcd/values.yaml` is
`2.7.x`. We install the latest `v2.7.x` CLI release at build time:

```bash
# Version detection
curl -sSL https://api.github.com/repos/fluxcd/flux2/releases \
  | jq -r '[.[] | select(.tag_name | startswith("v2.7.")) | .tag_name] | first'
# → v2.7.5

# URL format verified:
# https://github.com/fluxcd/flux2/releases/download/v2.7.5/flux_2.7.5_linux_arm64.tar.gz
# → HTTP/2 302 → HTTP/2 200  ✅
```

GHCR authentication for `flux push artifact` is handled by the existing
`docker login ghcr.io` step — flux uses the same Docker credential store.

Result: **PASS** (URL verified, auth path confirmed)

---

## What We Can Still Validate Locally

Before the next arm64 hardware cycle, the best repository-local checks are:

- run `git apply --check` on every patch against a clean `v1.3.3` clone
- run `make -n build` to verify the exact package order and confirm which
  packages are intentionally skipped
- audit the package Dockerfiles for any new hardcoded `amd64`, `x86_64`, or
  architecture-specific download URLs
- run targeted package builds for the riskiest steps (`kubeovn`, `cilium`,
  `core/installer`) instead of waiting for the full release workflow
- verify the build toolchain (`crane`, `helm`, `yq`, `flux`) is available on
  the runner architecture before we ask GitHub Actions to burn a full build

If we want stronger pre-hardware validation, a native arm64 AWS Graviton test
environment is the right next step. We should keep using the upstream Talos AMI
as the base there rather than producing a custom AMI; the goal is to validate
the CozyStack install flow, not image creation of the host OS.

---

## Resolved CI failures (before local validation was added)

| Run | Failure | Root cause | Fix |
|---|---|---|---|
| v1.3.3 run 1 | `E: Unable to locate package helm` | `ubuntu-24.04-arm` apt repos don't carry helm | PR #54: install from `get.helm.sh` tarball |
| v1.3.3 run 2 | linstor gradle/protoc `Syntax error: ")" unexpected` | amd64 ELF executed on arm64 | PR #55: skip linstor+linstor-gui in patch 07 |
| v1.3.3 run 3 | `Error: unknown flag: --all` in crane | `crane copy --all` does not exist; correct flag is `--platform all` | PR #56: fix patch 06 |
| v1.3.3 run 4 | `/bin/sh: 1: flux: not found` | `flux push artifact` needed by `core/installer`'s `image-packages` target; flux CLI not installed | PR #56: install flux v2.7.x from GitHub releases |
