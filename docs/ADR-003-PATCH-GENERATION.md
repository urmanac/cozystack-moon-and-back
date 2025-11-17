# ADR-003: Patch Generation Best Practices

**Date:** 2025-11-16  
**Status:** Accepted  
**Context:** CozyStack ARM64 Talos Image Build Pipeline  

## Summary

During development of ARM64 Talos image builds, we encountered significant issues with patch file generation that caused "patch fragment without header" and "corrupt patch" errors. This ADR documents the correct approach for generating Git patches.

## Problem

Initial attempts to create patch files manually resulted in malformed patches that Git could not apply:

```
error: patch fragment without header at line 33: @@ -80,6 +80,8 @@ input:
error: corrupt patch at line 13
```

The patches were created by manually writing unified diff format, which led to:
- Incorrect line numbers
- Missing proper Git headers
- Malformed hunk boundaries
- Missing newlines and proper termination
- Invalid multi-hunk structures

## Decision

**✅ CORRECT APPROACH: Use Git to generate patches**

```bash
# 1. Clone the target repository
git clone https://github.com/cozystack/cozystack.git
cd cozystack

# 2. Make actual file changes using sed/editor
sed -i 's/EXTENSIONS="drbd zfs"/EXTENSIONS="drbd zfs spin tailscale"/' packages/core/installer/hack/gen-profiles.sh
sed -i 's/arch: amd64/arch: arm64/' packages/core/installer/hack/gen-profiles.sh
sed -i 's|/usr/install/amd64/|/usr/install/arm64/|g' packages/core/installer/hack/gen-profiles.sh

# 3. Generate proper Git patch
git diff > my-changes.patch

# 4. Validate patch applies cleanly
git reset --hard HEAD
git apply --check my-changes.patch
git apply my-changes.patch
```

**❌ WRONG APPROACH: Manual patch construction**

```bash
# DON'T DO THIS - creates malformed patches
cat > broken.patch << 'EOF'
diff --git a/file.sh b/file.sh
@@ -5,7 +5,7 @@ some context
-old line
+new line
@@ -60,13 +60,13 @@ more context  # <-- WRONG: line numbers don't match reality
-another old line
+another new line
EOF
```

## Implementation

### Working Patch Structure

A proper Git-generated patch has:

```diff
diff --git a/packages/core/installer/hack/gen-profiles.sh b/packages/core/installer/hack/gen-profiles.sh
index bbe932d7..9f798c42 100755  # <-- Proper Git object hashes
--- a/packages/core/installer/hack/gen-profiles.sh
+++ b/packages/core/installer/hack/gen-profiles.sh
@@ -5,7 +5,7 @@ set -u                     # <-- Correct line numbers from actual file
 TMPDIR=$(mktemp -d)
 PROFILES="initramfs kernel iso installer nocloud metal"
 FIRMWARES="amd-ucode amdgpu bnx2-bnx2x i915 intel-ice-firmware intel-ucode qlogic-firmware"
-EXTENSIONS="drbd zfs"
+EXTENSIONS="drbd zfs spin tailscale"
 
 mkdir -p images/talos/profiles
```

### Validation Process

Always validate patches before committing:

```bash
# Quick validation script
#!/bin/bash
PATCH_FILE="$1"
REPO_URL="https://github.com/cozystack/cozystack.git"

# Test in clean environment
rm -rf /tmp/patch-test
git clone "$REPO_URL" /tmp/patch-test
cd /tmp/patch-test

# Validate patch
if git apply --check "$PATCH_FILE"; then
    echo "✅ Patch is valid"
    git apply "$PATCH_FILE"
    git status --porcelain
else
    echo "❌ Patch is invalid"
    exit 1
fi
```

## Consequences

### Benefits
- Patches apply cleanly without errors
- Correct line numbers automatically calculated
- Proper Git metadata preserved  
- Multi-file changes handled correctly
- Reproducible across different Git versions

### Costs
- Requires actual file modifications rather than text manipulation
- Need clean Git repository for patch generation
- Slightly more setup than manual string concatenation

## Examples

### Before (Broken Manual Patch)
```diff
diff --git a/packages/core/installer/hack/gen-profiles.sh b/packages/core/installer/hack/gen-profiles.sh
index bbe932d..new456 100755  # <-- Wrong hashes
--- a/packages/core/installer/hack/gen-profiles.sh
+++ b/packages/core/installer/hack/gen-profiles.sh
@@ -4,7 +4,7 @@ set -u         # <-- Wrong line numbers
 TMPDIR=$(mktemp -d)
@@ -61,13 +61,13 @@ for profile    # <-- Fragment without proper header
```

### After (Working Git-Generated Patch)
```diff
diff --git a/packages/core/installer/hack/gen-profiles.sh b/packages/core/installer/hack/gen-profiles.sh
index bbe932d7..9f798c42 100755  # <-- Correct Git hashes
--- a/packages/core/installer/hack/gen-profiles.sh
+++ b/packages/core/installer/hack/gen-profiles.sh
@@ -5,7 +5,7 @@ set -u         # <-- Correct line numbers
 TMPDIR=$(mktemp -d)
 PROFILES="initramfs kernel iso installer nocloud metal"
 FIRMWARES="amd-ucode amdgpu bnx2-bnx2x i915 intel-ice-firmware intel-ucode qlogic-firmware"
-EXTENSIONS="drbd zfs"
+EXTENSIONS="drbd zfs spin tailscale"
 
 mkdir -p images/talos/profiles
```

## Lessons Learned

1. **Don't guess at patch format** - Git's unified diff format has specific requirements
2. **Line numbers are critical** - Manual calculation leads to "fragment without header" errors  
3. **Git metadata matters** - Proper object hashes enable Git to validate patch integrity
4. **Test early, test often** - Always validate patches in clean environment before CI
5. **Automation beats manual work** - Let Git generate patches rather than string manipulation

## Related

- GitHub Actions workflow: `.github/workflows/build-talos-images.yml`
- Applied patch: `patches/01-arm64-spin-tailscale.patch`
- Validation script: `validate-patch.sh`

---

> **TL;DR**: Use `git diff` to generate patches, not manual string concatenation. The computer is better at calculating line numbers than humans. 🤖✨