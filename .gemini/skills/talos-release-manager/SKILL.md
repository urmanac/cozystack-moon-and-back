---
name: talos-release-manager
description: Executes the strict CI-validated release process for Cozystack Talos assets. Use this skill when asked to merge to main, tag a release, or publish a new version of the Cozystack Talos project.
---

# Talos Release Manager

## Overview

This skill ensures that all releases of the Cozystack Talos assets are robust, properly cached, and fully validated by CI. It prevents race conditions and "vibes-based" releases by enforcing a strict waiting period for the `main` branch CI before tagging, and ensures the Release Provenance Rubric guarantees exactly 31+ OCI images are successfully shipped.

## Release Process Workflow

Follow these steps exactly when cutting a new release.

### Step 1: Pre-Merge Validation
Before merging a Pull Request into `main`:
1. Verify the PR's CI pipeline has fully passed.
2. If tests are still running, use `gh run list` and wait. Do not merge on failure or in progress.

### Step 2: Merge to Main
1. Execute the merge: `gh pr merge --merge --delete-branch` (or instruct the user to do so).
2. Immediately switch your local environment to `main`: `git checkout main && git pull origin main`.

### Step 3: Wait for Main CI (The Iron Rule)
**CRITICAL: You MUST wait for the `main` branch CI (`build-talos-images.yml`) to pass completely before proceeding.** Tagging an unverified commit causes race conditions and corrupts the release cache.
1. Run `gh run list --branch main --workflow build-talos-images.yml --limit 1`.
2. Wait for the `STATUS` to be `completed` and the `CONCLUSION` to be `success`.
3. If it fails, halt the release process and inform the user.

### Step 4: Documentation (The Release Doc)
1. Ensure you have the latest validated commit: `git pull origin main`.
2. Create a new release document inside `docs/` named with an alphabetical code word (the next letter is N, e.g., `docs/NUTMEG-13-V1.4.0-1.13.2-2-RELEASE.md`). Previous letters were G-M (Galaxy, Hydrogen, Ion, Juniper, Kestrel, Lavender, Mint).
3. The release doc should outline the contents of the release, emphasizing the board-specific images (CM4 vs. CM5).

### Step 5: Tagging and Release
1. Create the new release tag. Be sure to use the correct revision syntax if updating an existing Talos/Cozystack combination (e.g., `v1.4.0-1.13.2-2`).
2. Run `git tag <tag-name>`.
3. Run `git push origin <tag-name>`.

### Step 6: Verify the Release Provenance Rubric
1. The new tag will trigger the `release-talos-assets.yml` workflow.
2. Monitor this workflow: `gh run list --branch <tag-name> --workflow release-talos-assets.yml --limit 1`.
3. Wait for it to complete. The workflow includes the **Release Provenance Rubric** step (`tests/custom-image/05-release-provenance.sh`), which will mathematically guarantee the presence of all 31+ expected OCI images.
4. Report the final success to the user.

## Known Gaps and Testing Strategy
**The Release Workflow Gap:** Because `release-talos-assets.yml` only triggers on version tags, its logic is NOT exercised in PR or `main` branch builds. 
*   Always perform a meticulous manual review of any changes to `.github/workflows/release-talos-assets.yml`.
*   Ensure that any shared logic between `build-talos-images.yml` and `release-talos-assets.yml` is kept in sync (or ideally moved to external scripts).
*   Until the release workflow is modularized into scripts, the first true test of its logic occurs *at tag time*.

