# Session Log: HailoRT Driver Upgrade to v5.3.0 (Part 3: Self-Hosted Runner & Cache Strategy)

**Date:** June 18, 2026
**Status:** CI Pipeline Redesign - Adapting for Self-Hosted Runners
**PRs:** 
- [urmanac/cozystack-moon-and-back#81](https://github.com/urmanac/cozystack-moon-and-back/pull/81) (Initial HailoRT v5.3.0 Integration, Merged)
- [urmanac/cozystack-moon-and-back#83](https://github.com/urmanac/cozystack-moon-and-back/pull/83) (CI/CD Integrity Fix, Merged)
- [urmanac/cozystack-moon-and-back#84](https://github.com/urmanac/cozystack-moon-and-back/pull/84) (CI Trigger Path Fix, Merged)
- [urmanac/cozystack-moon-and-back#85](https://github.com/urmanac/cozystack-moon-and-back/pull/85) (Sovereign OS Factory, Open)

## Overview
This segment addresses a critical failure encountered during the "Sovereign OS Factory" build on GitHub's hosted runners: "No space left on device" errors. This explicitly confirms the hypothesis that full kernel compilation for Talos Linux (alongside extensions) exceeds the resource limits of default GitHub Actions runners. The strategic decision is to transition the resource-intensive `build-sovereign-os` job to a self-hosted runner, leveraging persistent Buildx caching to optimize build times.

## Key Technical Hurdles & Resolutions (Part 3)

### 1. "No space left on device" during Kernel Compilation
-   **Problem**: Compiling the full Talos Linux kernel, `installer`, and `hailort` extension within the `build-sovereign-os` job consumed excessive disk space on GitHub-hosted runners, leading to build failures.
-   **Resolution**: The `build-sovereign-os` job will be migrated to a **self-hosted runner**. This provides dedicated and sufficient disk resources for large-scale builds.

### 2. Optimizing Buildx Cache for Self-Hosted Runners
-   **Problem**: Even on a self-hosted runner, rebuilding the entire kernel every time is inefficient. We need a persistent Buildx cache.
-   **Resolution**: Configured `docker/setup-buildx-action` in the `build-sovereign-os` job to utilize a `type=local` cache with a persistent destination (`/tmp/buildx-cache-${{ github.job }}`). On a self-hosted runner with a persistent `/tmp` or mounted volume, this will ensure that subsequent builds benefit from the cached layers, drastically reducing build times after the initial full compile.

### 3. Streamlining CI Job Execution
-   **Problem**: The `if: always()` condition for `build-sovereign-os` was removed.
-   **Resolution**: The `build-sovereign-os` job will now automatically execute based on its dependencies and trigger conditions, making the workflow more intuitive.

## Architectural Improvements (Self-Hosted Runner Integration)
The CI pipeline has been further refined to accommodate the self-hosted runner:

### Tier 1: The "Sovereign OS Factory" (`hack/build-sovereign-os.sh`) - Now on Self-Hosted
-   **Migration**: The `runs-on` property for `build-sovereign-os` is changed from `ubuntu-24.04-arm` to `[self-hosted, linux, arm64]`.
-   **Persistent Caching**: The Buildx setup now explicitly configures a local cache (`/tmp/buildx-cache-${{ github.job }}`) for persistent storage on the self-hosted runner. This makes subsequent builds (when the content hash of build logic remains unchanged) execute in seconds, effectively addressing the initial 1.5-hour compile time for repeated runs.

## Current Status & Expectations
-   The CI workflow has been updated to prepare for a self-hosted runner.
-   The `build-sovereign-os` job will now target custom, user-managed runners.
-   **Next Step**: Set up a self-hosted runner (e.g., on the MacBook Pro) and register it with the repository, ensuring it has the labels `self-hosted`, `linux`, and `arm64`, and sufficient disk space. Once the runner is active and the PR is merged, the `build-sovereign-os` job will execute on this dedicated hardware, leveraging its persistent cache for efficient builds.

**Required Action for User**: Set up a self-hosted GitHub Actions runner on a suitable machine (e.g., MacBook Pro) with ample disk space (recommended >100GB). Register the runner with the repository and assign it the labels `self-hosted`, `linux`, `arm64`.

---
**Related Documentation**:
- [ADR-005: Sovereign OS Factory for Hardware Extension Integration](ADRs/ADR-005-SOVEREIGN-OS-FACTORY.md)
