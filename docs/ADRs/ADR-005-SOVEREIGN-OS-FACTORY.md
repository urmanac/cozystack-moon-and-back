# ADR-005: Sovereign OS Factory for Hardware Extension Integration

**Date:** 2026-06-18  
**Status:** Proposed  
**Context:** Integration of Hailo-10H AI accelerator drivers (HailoRT v5.3.0) into Talos Linux for Raspberry Pi 5.

## Summary
This ADR establishes a new CI architecture: the "Sovereign OS Factory." This architecture allows us to build a custom Talos Linux kernel and `installer` image alongside our hardware extensions (like HailoRT 5.3.0), ensuring cryptographic signature alignment and resolving the "key was rejected by service" error. It also expands our build matrix to dynamically switch between standard upstream Talos artifacts and our custom-built sovereign artifacts based on hardware targets.

## Problem
1.  **Strict Module Signing:** Talos Linux kernels employ strong security measures, including ephemeral module signing keys generated during the kernel build. Any kernel module (like `hailo1x_pci`) not signed with the *exact* key used to compile the running kernel will be rejected, leading to hardware not being initialized or even boot failures.
2.  **Hailo 10H Driver Gap:** Upstream Sidero Labs Talos does not provide official `HailoRT v5.3.0` drivers, which are necessary for Hailo-10H hardware. We cannot rely on their pre-signed kernel modules.
3.  **Out-of-Band Build Issues:** Our previous approach of building the HailoRT extension in isolation (`hack/build-hailort.sh`) resulted in the driver being signed with a different key than the kernel, leading to rejection.
4.  **CI Build Matrix Limitations:** The existing CI workflow treated all Talos images as simple overlays on a single upstream base, lacking the granularity to differentiate hardware-specific kernel requirements.
5.  **GitHub Hosted Runner Resource Limits:** Compiling a full Linux kernel and related Talos images requires significant disk space and memory, exceeding the capacity of standard GitHub-hosted runners, resulting in "No space left on device" errors.

## Decision

**✅ CHOSEN: Implement a Two-Tiered CI Architecture with a Sovereign OS Factory and Self-Hosted Runners**

We will redefine our GitHub Actions CI pipeline to consist of two primary stages, with the resource-intensive "Sovereign OS Factory" leveraging self-hosted runners.

### Tier 1: The "Sovereign OS Factory" (`build-sovereign-os` job)
This new job (implemented in `hack/build-sovereign-os.sh`) will now run on **self-hosted runners** and will:
1.  **Download Sidero Sources:** Fetch pinned `siderolabs/pkgs`, `siderolabs/extensions`, and `siderolabs/talos` source repositories.
2.  **Compile Custom Kernel:** Build the `kernel` package from `siderolabs/pkgs` locally. This step generates our unique, ephemeral cryptographic signing key for the kernel.
3.  **Compile Custom Extension:** Build the `hailort` extension from `siderolabs/extensions` using the `kernel-build` stage produced in step 2. This ensures the extension is signed with the *exact same key* as our custom kernel.
4.  **Compile Custom Installer:** Build the `installer-base` and `installer` images from `siderolabs/talos`, overriding the `PKG_KERNEL` variable to point to our custom-built kernel. This wraps our sovereign kernel in a standard Talos installer image.
5.  **Publish Sovereign Artifacts:** Push the custom `urmanac/installer:<unique-hash>` and `urmanac/hailort:<unique-hash>` images to GHCR.
6.  **Idempotency & Tagging:** Utilize content-based hashing (`UNIQUE_TAG`) to skip rebuilding if nothing has changed. On `main` branch pushes, update stable tags (`5.3.0-v1.13.3`, `5.3.0`) to point to these verified artifacts.

### Tier 2: The "Assembly Matrix" (`build-cozystack-upstream` job)
This job will be modified to expand its build matrix and dynamically inject artifacts:
1.  **Expanded Matrix:** Introduce a new `hardware` dimension (e.g., `[cm4-standard, cm5-hailo10h]`) alongside the existing `extension_variant`.
2.  **Dynamic Artifact Injection:**
    *   **`cm4-standard` (Default/Fast Path):** Uses the standard `ghcr.io/siderolabs/installer` and `ghcr.io/siderolabs/hailort` (or other upstream extensions) for standard CM4 nodes. These builds will remain fast.
    *   **`cm5-hailo10h` (Exotic/Heavy Path):** Intercepts the `gen-profiles.sh` process. It injects the `INSTALLER_IMAGE` and `HAILORT_IMAGE` environment variables from the outputs of the `build-sovereign-os` job. This forces the Talos image assembly to use our custom kernel and signed HailoRT driver.

## Alternatives Considered
*   **Attempt to share Sidero Labs' `kernel-build`:** Explored pointing our `bldr` builds to `ghcr.io/siderolabs/kernel-build`. Rejected because Sidero Labs' `kernel-build` images are private, making it impossible to align signing keys without their internal build infrastructure.
*   **Disable Module Signing (Unfeasible):** Talos Linux is designed around immutability and security. Disabling kernel module signing would compromise the integrity of the OS, is not officially supported, and would introduce significant security risks.
*   **Waiting for Upstream HailoRT 5.x Support:** While ideal, the timeline for upstream Sidero Labs to integrate HailoRT v5.3.0 (or newer) is uncertain. Our project requires immediate support for Hailo-10H.
*   **Optimizing GitHub Hosted Runners:** Attempted to reduce disk usage on hosted runners. Rejected as kernel compilation is inherently disk/memory intensive and consistently exceeds free-tier limits.

## Consequences
**Positive:**
*   ✅ **Resolves "Key Rejected" Error:** Ensures cryptographic signature alignment between the kernel and the `hailo1x_pci` module.
*   ✅ **Robust Hardware Support:** Provides a reliable method for integrating custom hardware drivers that are not upstream-supported by Talos.
*   ✅ **Flexible Build Matrix:** Allows for differentiated builds and testing across various hardware/extension combinations.
*   ✅ **Maintainable Idempotency:** The Sovereign OS Factory leverages content-hashing to ensure fast, repeatable builds.
*   ✅ **Persistent Build Caching:** Self-hosted runners enable persistent Buildx caching, drastically reducing subsequent build times for the Sovereign OS Factory.
*   ✅ **Extensibility:** The factory can be expanded to build other custom kernel modules or even custom `spin` or `tailscale` variants if needed in the future.

**Negative:**
*   ⚠️ **Requires Self-Hosted Runners:** The `build-sovereign-os` job now requires a dedicated self-hosted runner with sufficient resources (disk, memory, ARM64 architecture) due to the demands of full kernel compilation.
*   ⚠️ **Increased Complexity:** Introduces a more sophisticated CI/CD pipeline, requiring careful management of `bldr` commands across multiple Sidero repositories.
*   ⚠️ **Maintenance Overhead:** We are now responsible for maintaining our custom kernel build process, including pinning Sidero `pkgs` and `talos` to specific versions, and managing the self-hosted runner infrastructure.

**Neutral:**
*   🔄 **Expanded Registry:** We will be pushing custom `urmanac/installer` and `urmanac/kernel` images to GHCR alongside our existing extension images.

---

**Next ADR:** [ADR-006: Kubernetes OCI Image Management and Multi-Architecture Builds](ADR-006-KUBERNETES-OCI-IMAGE-MANAGEMENT-AND-MULTI-ARCHITECTURE-BUILDS.md)

---

📍 **Navigation**: [Home](../../README.md) | [Documentation Index](../README.md)
