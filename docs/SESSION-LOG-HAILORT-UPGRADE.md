# Session Log: HailoRT Driver Upgrade to v5.3.0 (Part 3: Self-Hosted Runner & Cache Strategy)

**Date:** June 20, 2026
**Status:** CI Pipeline Redesign - Persistent Cache & Signature Alignment Completed
**PRs:** 
- [urmanac/cozystack-moon-and-back#81](https://github.com/urmanac/cozystack-moon-and-back/pull/81) (Initial HailoRT v5.3.0 Integration, Merged)
- [urmanac/cozystack-moon-and-back#83](https://github.com/urmanac/cozystack-moon-and-back/pull/83) (CI/CD Integrity Fix, Merged)
- [urmanac/cozystack-moon-and-back#84](https://github.com/urmanac/cozystack-moon-and-back/pull/84) (CI Trigger Path Fix, Merged)
- [urmanac/cozystack-moon-and-back#85](https://github.com/urmanac/cozystack-moon-and-back/pull/85) (Sovereign OS Factory, Open)

## Overview
This segment addresses a critical failure encountered during the "Sovereign OS Factory" build on GitHub's hosted runners: "No space left on device" errors. This explicitly confirms the hypothesis that full kernel compilation for Talos Linux (alongside extensions) exceeds the resource limits of default GitHub Actions runners. The strategic decision is to transition the resource-intensive `build-sovereign-os` job to a self-hosted runner, leveraging persistent Buildx caching to optimize build times.

---

## Key Technical Hurdles & Resolutions (Part 3)

### 1. "No space left on device" during Kernel Compilation
-   **Problem**: Compiling the full Talos Linux kernel, `installer`, and `hailort` extension within the `build-sovereign-os` job consumed excessive disk space on GitHub-hosted runners, leading to build failures.
-   **Resolution**: The `build-sovereign-os` job was migrated to a **self-hosted runner**, providing dedicated and sufficient disk resources for large-scale builds.

### 2. Optimizing Buildx Cache for Self-Hosted Runners
-   **Problem**: Even on a self-hosted runner, rebuilding the entire kernel every time is inefficient. We need a persistent Buildx cache.
-   **Resolution**: Configured `docker/setup-buildx-action` in the `build-sovereign-os` job to utilize a `type=local` cache with a persistent destination (`/tmp/buildx-cache-${{ github.job }}`). On a self-hosted runner with a persistent `/tmp` or mounted volume, this ensures subsequent builds benefit from cached layers, drastically reducing build times after the initial compile.

---

## Key Technical Hurdles & Resolutions (Part 4 - June 19 & 20, 2026)

### 3. Talos Upgrade Pre-flight Version Blocker
-   **Problem**: Upgrading custom-built installers failed with `Error: pre-flight checks failed: upgrades to version 5.3.0-v1.13.3-3d4c9177e9d4 are not supported`. This was because Sidero's Makefiles compile the value of the `TAG` variable directly into the installer binaries. Passing our content-hashed `UNIQUE_TAG` made the binary report a version that Talos's upgrade pre-flight checks rejected.
-   **Resolution**: Modified `hack/build-sovereign-os.sh` to compile Sidero targets with `TAG="$TALOS_VERSION"` (i.e. `v1.13.3`). Once pushed to GHCR, the script queries the image digests and uses `crane tag` to explicitly tag them with the content-hashed `UNIQUE_TAG`. This preserves both standard version compliance inside the binaries and immutable caching in the registry.

### 4. Buildx Local Folder Caching in Sibling Containers
-   **Problem**: Sidero's Makefiles used `CI_ARGS` to read and write cache to `/tmp/buildx-cache`. Since the BuildKit daemon container runs as an isolated sibling container on the host Docker daemon, it had no access to the runner's local filesystem and wrote cache to an ephemeral path, resulting in a cache miss every run. Additionally, the default setup deleted the builder container at the end of the run.
-   **Resolution**: Named the builder container `sovereign-builder` and configured it with `cleanup: false` and `keep-state: true` in `.github/workflows/build-talos-images.yml`. We cleared the directory-based `CI_ARGS` cache configurations. Buildx now natively and automatically manages caching internally inside the persistent `sovereign-builder` container volume.

### 5. Buildx Cache Invalidation due to Dynamic Git Commits
-   **Problem**: Sidero's Makefiles dynamically set `SOURCE_DATE_EPOCH` and `TAG` using the local git commit timestamp/status. Since the build script dynamically ran `git init` and `git commit` to apply patches on every execution, these variables changed every run, invalidating BuildKit's cache and causing a full 1h 45m kernel compilation.
-   **Resolution**: Passed `SOURCE_DATE_EPOCH=1716646524` and `TAG="$TALOS_VERSION"` explicitly as command-line arguments to all Sidero `make` calls in `build-sovereign-os.sh` to enforce build determinism and preserve cache hits.

### 6. Cryptographic Module Signing Key Mismatch ("key was rejected by service")
-   **Problem**: Talos Linux enforces strict module signing (`module.sig_enforce=1`). The kernel compilation generates a fresh, ephemeral private signing key on every compile. Because we were only building the `kernel` target in Step 1, the `hailort-pkg` target (containing the actual compiled `.ko` driver modules) was being pulled as a stale/unsigned image from the registry. The booted kernel (Key A) rejected the module signed with a mismatched key (Key B), resulting in the boot log error:
    `error loading module "hailo1x_pci": load hailo1x_pci failed: key was rejected by service`
-   **Resolution**: Modified Step 1 of `hack/build-sovereign-os.sh` to build both `kernel` and `hailort-pkg` in the same invocation:
    `$MAKE_CMD kernel hailort-pkg REGISTRY="$REGISTRY" USERNAME="$USERNAME" TAG="$PKG_VERSION_TAG" PUSH=true PLATFORM=linux/arm64`
    This guarantees that the driver module is compiled against the newly generated kernel headers and signed with the exact private key matching the booted kernel.

### 7. Kubelet CPU Manager Boot Failure & Talos Fallback Revert
-   **Problem**: Upon boot of the upgraded image, Kubelet failed to start with `start cpu manager error: current set of available CPUs "0" doesn't match with CPUs in state "0-3"`. This occurred because Kubelet has a persistent CPU state checkpoint file (`/var/lib/kubelet/cpu_manager_state`) on the node's local storage. When the upgraded kernel booted, only CPU 0 was brought online during early initialization. Detecting a mismatch, Kubelet failed, causing Talos to mark the boot as failed and automatically roll back (revert) to the old working partition (which then triggered module signature errors because it ran the old kernel).
-   **Resolution**: Deleting the Kubelet CPU Manager checkpoint state file allows Kubelet to re-detect all available cores on boot.

---

## Architectural Improvements (Self-Hosted Runner Integration)
The CI pipeline has been further refined to accommodate the self-hosted runner:

### Tier 1: The "Sovereign OS Factory" (`hack/build-sovereign-os.sh`) - Now on Self-Hosted
-   **Migration**: The `runs-on` property for `build-sovereign-os` is changed from `ubuntu-24.04-arm` to `[self-hosted, linux, arm64]`.
-   **Persistent Caching**: The Buildx setup now uses a persistent named builder container (`sovereign-builder`) with `cleanup: false` and `keep-state: true`. Local cache parameters (`CI_ARGS`) have been replaced with native internal BuildKit volume caching.

---

## Current Status & Expectations
-   The CI workflow has been updated to prepare for a self-hosted runner.
-   The `build-sovereign-os` job will now target custom, user-managed runners.
-   **Required Action for User**: Before/during node upgrade, delete the Kubelet CPU Manager checkpoint file to prevent rollback loops:
    `rm -f /var/lib/kubelet/cpu_manager_state`

---
**Related Documentation**:
- [ADR-005: Sovereign OS Factory for Hardware Extension Integration](ADRs/ADR-005-SOVEREIGN-OS-FACTORY.md)
