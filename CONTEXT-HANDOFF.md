# CONTEXT HAND-OFF: HailoRT v5.3.0 Upgrade & Sovereign OS Factory

**Date:** June 18, 2026
**Current Gemini Model:** Downgraded (Gemini-2.5-Flash)

---

## 🚀 Project Goal & Journey Summary

The primary objective of this session was to successfully upgrade the Talos Linux HailoRT extension to **v5.3.0** to support the **Hailo-10H AI accelerator** (Raspberry Pi AI HAT+) within the CozyStack Moon-and-Back project. This involved fully automating the source build within the GitHub Actions CI pipeline and ensuring functional deployment on Raspberry Pi 5 nodes.

Our journey evolved through several critical phases, driven by the immutable and cryptographically secured nature of Talos Linux.

---

## 🚧 Key Challenges & Solutions Implemented

### 1. HailoRT v5.3.0 Kernel Compatibility
*   **Challenge**: The HailoRT v5.3.0 driver source used the deprecated `del_timer_sync` function, which caused compilation failures on modern kernels (like Talos's `6.18.33`).
*   **Solution**: Implemented a `perl` patch in `patches/13-hailort-v5.3.0-pkgs.patch` to replace `del_timer_sync` with `timer_delete_sync` during the build process, allowing successful compilation.

### 2. Firmware Symlink Integrity for RPi5 Boot
*   **Challenge**: The Hailo-10H firmware tarball contains symlinks (e.g., `u-boot-default.dtb.signed` -> `u-boot-0.dtb.signed`). The Talos imager's file processing (`os.Stat`) during image assembly was causing `ENOENT` errors and boot failures on RPi5 when encountering these symlinks due to a race condition (moving the target before the symlink itself).
*   **Solution**: Modified `patches/13-hailort-v5.3.0-pkgs.patch` to include a robust symlink dereferencing step. All symlinks in the firmware directory are now explicitly replaced with copies of their targets, ensuring the imager only deals with concrete files.

### 3. GitHub Container Registry (GHCR) Permissions
*   **Challenge**: Initial CI pushes to GHCR failed with `403 Forbidden` errors, as the GitHub Actions app lacked "Write" permissions for new package namespaces.
*   **Solution**: User manually granted "Write" access to the Actions app for `hailort` and `hailort-pkg` packages in GHCR.

### 4. CI/CD Integrity & Content-Based Tagging
*   **Challenge**: The CI pipeline was susceptible to "tag squatting" from feature branches. `main` would skip builds if a tag already existed, even if the content was from a failed or unverified PR build. This led to `MANIFEST_UNKNOWN` errors in downstream Talos image builds.
*   **Solution**: Implemented a **content-based tagging strategy**.
    *   `hack/build-sovereign-os.sh` now calculates a `CONTENT_HASH` from build logic and patches.
    *   All builds (PR or main) push to a unique, immutable tag (e.g., `5.3.0-v1.13.3-f619767`).
    *   Only `main` branch pushes update the stable, production-ready tags (`5.3.0`, `5.3.0-v1.13.3`), pointing them to the latest *verified* content hash.

### 5. CI Trigger Path Insufficiency
*   **Challenge**: Changes to `hack/` directory (where build scripts reside) were not triggering CI builds on `main` dues to restrictive `on.push.paths` filters.
*   **Solution**: Updated `.github/workflows/build-talos-images.yml` to include `hack/**` and `VERSION` in the CI trigger paths, ensuring all relevant changes initiate a build.

### 6. Critical Blocker: Kernel Module Signature Rejection ("key was rejected by service")
*   **Challenge**: Talos Linux strictly enforces cryptographic signing for kernel modules. Our isolated `hailort` extension build (`hack/build-hailort.sh`) produced a module signed by a different ephemeral key than the official Sidero Labs kernel in the base OS, leading to immediate rejection at boot. Sidero Labs' `kernel-build` stages are private, preventing direct alignment.
*   **Solution**: Designed and implemented the **Sovereign OS Factory** architecture (documented in `docs/ADRs/ADR-005-SOVEREIGN-OS-FACTORY.md`).

---

## 🏗️ Architectural Evolution: The Sovereign OS Factory

The solution to the module signing issue led to a significant redesign of our CI pipeline into a two-tiered system:

**Tier 1: The "Sovereign OS Factory" (`build-sovereign-os` job)**
*   **Purpose**: To build custom, cryptographically aligned Talos kernel, installer, and hardware extension images.
*   **Implementation**: New script `hack/build-sovereign-os.sh` (renamed from `build-hailort.sh`).
*   **Process**:
    1.  Downloads pinned `siderolabs/pkgs`, `siderolabs/extensions`, and `siderolabs/talos` source.
    2.  Compiles a custom **Talos `kernel`** within the `pkgs` context (generating our unique signing key).
    3.  Compiles the **`hailort` extension** using the locally built `kernel-build` stage (ensuring it's signed by the *same key* as our custom kernel).
    4.  Compiles a custom **Talos `installer-base` and `installer`** (wrapping our sovereign kernel) within the `talos` context.
    5.  Publishes these artifacts (e.g., `urmanac/installer:5.3.0-v1.13.3-<hash>`, `urmanac/hailort:5.3.0-v1.13.3-<hash>`) to GHCR.
*   **Benefit**: Ensures cryptographic signature alignment between kernel and modules, resolving "key was rejected" error.

**Tier 2: The "Assembly Matrix" (`build-cozystack-upstream` job)**
*   **Purpose**: To assemble final Talos OS images for various hardware and extension combinations.
*   **Implementation**: Modified `build-cozystack-upstream` job in `.github/workflows/build-talos-images.yml`.
*   **Process**:
    1.  **Expanded Matrix**: Now includes a `hardware` dimension (`cm4-standard`, `cm5-hailo10h`) and `extension_variant`.
    2.  **Dynamic Injection**:
        *   `cm4-standard` path continues to use official upstream Sidero artifacts.
        *   `cm5-hailo10h` path intercepts `gen-profiles.sh` to inject our custom `INSTALLER_IMAGE` and `HAILORT_IMAGE` outputs from the `build-sovereign-os` job.
*   **Benefit**: Allows building both standard and exotic hardware images, ensuring custom drivers are built on a matching kernel.

---

## 🛑 Latest Challenge: GitHub Hosted Runner Resource Limits

*   **Challenge**: The "Sovereign OS Factory" (Tier 1) job failed during kernel compilation on GitHub's hosted runners with "No space left on device" errors, confirming it requires more resources than publicly available.
*   **Solution**: The `build-sovereign-os` job **must run on a self-hosted GitHub Actions runner** with ample disk space and persistent storage for the Buildx cache.

---

## ✅ Current State of the Code & Next Steps for You

All the code changes for the Sovereign OS Factory, self-hosted runner configuration, and documentation updates are currently committed locally to your `feat/sovereign-os-factory` branch and are awaiting integration.

**Your Critical Next Steps:**

1.  **Set Up Self-Hosted Runner:**
    *   On a suitable machine (e.g., your MacBook Pro), install the GitHub Actions runner application.
    *   Register it with your repository.
    *   Assign it the exact labels: `self-hosted`, `linux`, `arm64`.
    *   Ensure it has **ample disk space** (100GB+ recommended) and Docker/Buildx installed.
    *(Refer to GitHub's documentation for detailed self-hosted runner setup instructions.)*

2.  **Merge Pull Request #85:**
    *   Review `urmanac/cozystack-moon-and-back#85`.
    *   Merge this PR into `main`.

3.  **Monitor CI Build:**
    *   The merge to `main` will trigger a new CI run.
    *   The `build-sovereign-os` job should now pick up your self-hosted runner.
    *   The first run will perform a full kernel compilation (~1.5 hours). Subsequent runs (if build content hasn't changed) will be fast due to persistent Buildx caching.

4.  **Deploy Patched Talos OS:**
    *   Once the `main` branch build successfully completes, new Talos installer images for `cm5-hailo10h` will be available in GHCR, containing your custom kernel and signed HailoRT v5.3.0 driver.
    *   Use `talosctl upgrade` or a clean install with the newly minted `talos:v1.13.3-rpi5-cm5-hailo10h` image.

5.  **Run Ollama Smoke Test (Provided Previously):**
    *   Deploy the `ollama-hailo.yaml` manifest to your cluster.
    *   Verify the `/dev/h1x-0` device is present and Ollama can utilize the Hailo-10H accelerator.

---

## 📚 Key Files Modified/Created

*   `hack/build-sovereign-os.sh`: **(New)** Core script for building custom kernel, installer, and extension.
*   `patches/01-arm64-spin-tailscale.patch`: Updated to allow `INSTALLER_IMAGE` override.
*   `patches/03-arm64-spin-only.patch`: Updated to allow `INSTALLER_IMAGE` override.
*   `patches/08-arm64-spin-hailort.patch`: Updated to allow `INSTALLER_IMAGE` override, and HailoRT image override.
*   `patches/09-arm64-rpi5-spin-hailort.patch`: Updated to allow `INSTALLER_IMAGE` override.
*   `patches/12-hailort-v5.3.0-extension.patch`: Updated HailoRT version and manifest description.
*   `patches/13-hailort-v5.3.0-pkgs.patch`: Updated HailoRT version, firmware URLs, symlink dereferencing, and `del_timer_sync` fix.
*   `.github/workflows/build-talos-images.yml`:
    *   Introduced `build-sovereign-os` job targeting self-hosted runners.
    *   Expanded `build-cozystack-upstream` matrix with `hardware` dimension.
    *   Added logic to inject sovereign artifacts (`INSTALLER_IMAGE`, `HAILORT_IMAGE`) into the `cm5-hailo10h` path.
    *   Configured persistent Buildx caching.
*   `docs/ADRs/ADR-005-SOVEREIGN-OS-FACTORY.md`: **(New)** Documents the architectural decision for the Sovereign OS Factory.
*   `docs/ADRs/README.md`: Updated to index `ADR-005`.
*   `docs/SESSION-LOG-HAILORT-UPGRADE.md`: Updated with comprehensive session log details.
*   `docs/LATEST-BUILD.md`: Adjusted Talos version sourcing.

---

It has been an absolute privilege and an honor to work with you on this incredibly complex and rewarding challenge. Your patience, expertise, and willingness to adapt to unforeseen complexities (and model downgrades!) have been exceptional. I wish you the very best in the future, regardless of the platform.

Thank you!

---
(This document is locally committed to your `feat/sovereign-os-factory` branch.)
