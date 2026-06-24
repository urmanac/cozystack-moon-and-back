# CI/CD Roadmap: From Vibes to SLSA Build Level 3

## Overview
This document outlines the evolutionary steps required to transform our current release process from a fragile, "vibes-based" manual tagging system into a robust, high-integrity pipeline that aligns with DevOps agility and SLSA principles.

## Current State (Post NUTMEG-13)
- **Consolidated Scripting:** Patching logic moved from YAML into `hack/patch-talos.sh`.
- **Load-Bearing Versioning:** The `VERSION` file is now the single source of truth.
- **Automated Mutable Tagging:** The `main` branch CI forcibly syncs the Git tag to match the `VERSION` file, triggering automated releases with updated base images.
- **Artifact-Aware Rubric:** Verification script (`05-release-provenance.sh`) uses `crane` to validate both images and Flux OCI artifacts.

## Phase 1: Script Modularization (Agility)
**Goal:** Reduce "YAML Bloat" and enable local testing of the CI pipeline.
- **Action:** Move the entire "Build Talos Variants" logic into a modular script (e.g., `hack/build-talos.sh`).
- **Benefit:** Allows a developer to run the exact same build process locally that runs in CI, surfacing failures *before* a PR is even opened.

## Phase 2: SHA256 Manifest Pinning (SLSA Level 2)
**Goal:** Guarantee that release tags are promotions of verified "canary" builds.
- **Action:** 
  1. Update `main` CI to output a **Provenance Ledger** (e.g., `LATEST_BUILD.json`) containing the exact `sha256` digest for every built image.
  2. Modify the Release workflow to use `skopeo copy` or `crane tag` to promote these exact manifests to the release tag.
- **Benefit:** Release tagging becomes an O(1) operation (seconds instead of minutes) and provides mathematical certainty of the artifacts' contents.

## Phase 3: Immutable Release Revisions (SLSA Level 3)
**Goal:** Prevent accidental invalidation of proven releases while allowing security freshness.
- **Action:** Enforce a strict revision regime where tags like `v1.4.0-1.13.2-1` are immutable once published. Updates to base images must increment to `-2`.
- **Benefit:** Full air-gap readiness and complete predictability for downstream users who depend on tag stability.

## Phase 4: Shift-Left Hardware Validation
**Goal:** Expose hardware-specific failures (like the RPi5 networking issue) before they reach the main branch.
- **Action:** Integrate a "Hardware Dry-Run" stage in PR CI that validates Device Tree overlays and kernel module bindings for specialized boards (CM4, CM5).
