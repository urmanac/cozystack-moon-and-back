# ROSEMARY-18 (v1.5.0-1.13.5-1) Release Notes

## Overview
The **ROSEMARY-18** release upgrades upstream **CozyStack to v1.5.0** (bringing UI dashboard improvements, core controller updates, and stability fixes) and **Talos Linux to v1.13.5** (incorporating Linux kernel 6.18.36, containerd 2.2.5, and ZFS 2.4.3).

This release bumps system components to the latest security patchlevels, pins the sovereign kernel build to the Sidero pkgs tag `v1.13.0-36-g6b315f7`, and aligns the workflow builds with the clean OCI namespaces defined in the OCI Package Audit.

## Key Changes
1. **CozyStack upstream v1.5.0 Alignment**:
   - Pulled the latest upstream minor version release including system-wide packages, UI dashboard enhancements, and API updates.
2. **Talos upstream v1.13.5 Alignment**:
   - Upgraded default inputs to `v1.13.5` and pinned the custom signed sovereign kernel to the Sidero pkgs tag `v1.13.0-36-g6b315f7`.
   - Incorporates Linux kernel `6.18.36`, ZFS `2.4.3`, and Containerd `2.2.5` with critical CVE fixes.
3. **CI/CD Build Synchronization**:
   - Updated [build-sovereign-os.sh](file:///Users/yebyen/u/c/cozystack-moon-and-back/hack/build-sovereign-os.sh) and [build-hailort.sh](file:///Users/yebyen/u/c/cozystack-moon-and-back/hack/build-hailort.sh) to download Sidero extensions and pkgs for `v1.13.5` and use `PKG_VERSION_TAG="v1.13.0-36-g6b315f7"`.

## Strategy & Validation Summary
All upgrade plans are integrated into the current branch and validated:
- **Version bump**: Bumped `VERSION` file to `v1.5.0-1.13.5-1`.
- **Sovereign builds**: Updated Sidero package hash pins to `6b315f7` for kernel 6.18.36 compile logic.
- **Local test suite**: All check patches, syntax, and dependency checks pass cleanly.

## Usage for Hailo-10H
To enable the Hailo-10H driver on a Talos node, add the following to your machine configuration:

```yaml
machine:
  kernel:
    modules:
      - name: hailo1x_pci
```

*Note: For Hailo-8 series, the module name remains `hailo_pci`.*

## Artifacts

### OCI Images
**Talos Installer (Upgrades)**
- Generic (CM4): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos:v1.13.5`
- RPi5 (CM5): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos:v1.13.5-rpi5`

**Matchbox (Netboot)**
- Generic (CM4): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox:talos-v1.13.5-cozy-v1.5.0`
- RPi5 (CM5): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox:talos-v1.13.5-cozy-v1.5.0-rpi5`

### Flashable Metal Images
- CM4: `talos-metal-arm64-spin-hailort-talos-v1.13.5-cozy-v1.5.0.raw.xz`
- CM5: `talos-metal-rpi5-arm64-spin-hailort-talos-v1.13.5-cozy-v1.5.0.raw.xz`

## Future Roadmap & Plans
1. **CozyStack Dashboard ARM64 Support**: The upstream dashboard currently lacks native ARM64 support (which is why it is patched out of our active build groups via [07-arm64-skip-amd64-only-builds.patch](file:///Users/yebyen/u/c/cozystack-moon-and-back/patches/07-arm64-skip-amd64-only-builds.patch)). Due to high interest in running the dashboard natively on ARM64, we plan to implement custom image compiling for the dashboard in a future release.
2. **Upgrade to Spin v0.25+ / Spin v4.0.0 Support**: We aim to integrate the latest Spin container runtime shim updates (e.g. `v0.25.1` or later) once the upstream project supports it. This will allow for testing and running Spin v4 WebAssembly workloads on our sovereign Talos clusters.

