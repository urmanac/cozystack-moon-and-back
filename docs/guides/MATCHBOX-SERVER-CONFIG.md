# Matchbox Server Configuration for Custom Talos Images

## Overview

This guide documents how to boot ARM64 hosts (including Raspberry Pi CM4 with UEFI) using dnsmasq + matchbox, with images produced by this repository.

## Image Types

- `metal-arm64.raw.xz`: flashable bare-metal image for SD/eMMC/NVMe (best for CM4 bring-up).
- `nocloud-arm64.raw.xz`: VM/cloud-style image that expects NoCloud datasource metadata.

For PXE netboot, you normally serve kernel/initramfs from the Talos OCI image and install to disk with the Talos installer image.

## Current OCI Image Layout

Published images used by this repo:

- Talos installer/image payload (spin-only):
  - `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/talos:<tag>`
- Matchbox server (spin-only):
  - `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/matchbox:<tag>`
- Spin + Tailscale variant:
  - `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/talos:<tag>`
  - `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/matchbox:<tag>`
- Operator:
  - `ghcr.io/urmanac/cozystack-assets/cozystack-operator:<tag>`

Use either `:latest` (rolling) or a release tag like `:v1.3.3`.

## Recommended PXE Flow for CM4

1. dnsmasq serves DHCP + TFTP.
2. ARM64 clients (`client-arch=12`) chainload an ARM64 UEFI iPXE binary (`bootaa64.efi`).
3. iPXE fetches `http://<matchbox-host>:8080/boot.ipxe`.
4. matchbox serves kernel/initramfs and Talos config.

## Host Preparation

```bash
sudo mkdir -p /opt/matchbox/{assets,profiles,groups,ignition}
sudo chown -R "$USER":"$USER" /opt/matchbox
```

## Pull and Extract Talos Assets

Use the same variant you intend to install. Example uses `spin-only`:

```bash
docker pull ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/talos:latest

mkdir -p /opt/matchbox/assets/talos/arm64
cid=$(docker create ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/talos:latest)
docker cp "$cid":/assets/talos/arm64/. /opt/matchbox/assets/talos/arm64/
docker rm "$cid"

ls -lah /opt/matchbox/assets/talos/arm64
```

## Ensure UEFI Bootloader Files Exist in TFTP Root

For mixed environments, these are commonly required:

- `undionly.kpxe` for BIOS x86 (arch 0)
- `ipxe.efi` for x86 UEFI (arch 6/7/9)
- `bootaa64.efi` for ARM64 UEFI (arch 12)

If your dnsmasq image does not bundle ARM64 iPXE binaries, copy `bootaa64.efi` from your platform package/build into `/opt/matchbox/assets`.

## Start Matchbox

```bash
docker rm -f matchbox 2>/dev/null || true
docker run -d --name matchbox --net=host \
  -v /opt/matchbox:/var/lib/matchbox \
  ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/matchbox:latest \
  -address=0.0.0.0:8080 \
  -rpc-address=0.0.0.0:8081 \
  -log-level=debug
```

## Start dnsmasq (DHCP + TFTP)

Set these values for your network before running:

- `IFACE` (for example `eth0`)
- DHCP range
- gateway address
- DNS server address
- matchbox host IP/URL

```bash
docker rm -f dnsmasq 2>/dev/null || true
docker run -d --name dnsmasq --net=host --cap-add=NET_ADMIN \
  -v /opt/matchbox/assets:/var/lib/tftpboot:ro \
  quay.io/poseidon/dnsmasq:v0.5.0-32-g4327d60-amd64 \
  -d -q -p0 \
  --interface=eth0 \
  --bind-interfaces \
  --dhcp-range=10.20.13.150,10.20.13.200 \
  --dhcp-option=option:router,10.20.13.1 \
  --dhcp-option=option:dns-server,10.20.13.140 \
  --enable-tftp \
  --tftp-root=/var/lib/tftpboot \
  --dhcp-match=set:bios,option:client-arch,0 \
  --dhcp-boot=tag:bios,undionly.kpxe \
  --dhcp-match=set:efi32,option:client-arch,6 \
  --dhcp-boot=tag:efi32,ipxe.efi \
  --dhcp-match=set:efibc,option:client-arch,7 \
  --dhcp-boot=tag:efibc,ipxe.efi \
  --dhcp-match=set:efi64,option:client-arch,9 \
  --dhcp-boot=tag:efi64,ipxe.efi \
  --dhcp-match=set:efiarm64,option:client-arch,12 \
  --dhcp-boot=tag:efiarm64,bootaa64.efi \
  --dhcp-userclass=set:ipxe,iPXE \
  --dhcp-boot=tag:ipxe,http://10.20.13.140:8080/boot.ipxe \
  --log-queries \
  --log-dhcp
```

## Minimal Matchbox Profile/Group

Profile example:

```json
{
  "id": "cozystack-arm64",
  "name": "CozyStack ARM64 spin-only",
  "boot": {
    "kernel": "/assets/talos/arm64/vmlinuz",
    "initrd": ["/assets/talos/arm64/initramfs.xz"],
    "args": [
      "talos.platform=metal",
      "talos.config=http://10.20.13.140:8080/ignition?uuid=${uuid}",
      "console=tty0"
    ]
  }
}
```

Group example:

```json
{
  "id": "default",
  "name": "Default ARM64 group",
  "profile": "cozystack-arm64",
  "selector": {
    "arch": "arm64"
  }
}
```

## Talos Install Image Reference

In machine config, point to the same Talos variant/tag:

```yaml
machine:
  install:
    disk: /dev/mmcblk0
    image: ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/talos:latest
    wipe: false
```

For CM4 eMMC boot, disk may be `/dev/mmcblk0`; for USB/NVMe, use the appropriate `/dev/...`.

## Validation Checklist

```bash
# Containers up
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

# Matchbox serving assets
curl -f http://10.20.13.140:8080/assets/talos/arm64/vmlinuz >/dev/null
curl -f http://10.20.13.140:8080/assets/talos/arm64/initramfs.xz >/dev/null

# DHCP/TFTP logs
docker logs --tail=100 dnsmasq

# Matchbox logs
docker logs --tail=100 matchbox
```

## Common ARM64 PXE Pitfalls

- Wrong arch code: ARM64 UEFI clients are `option:client-arch,12`.
- Missing `bootaa64.efi` in TFTP root.
- Serving x86 `ipxe.efi` to ARM64 clients.
- Talos install image tag mismatch between matchbox profile and machine config.

## Notes for PR/Release Documentation

- Tag releases publish flashable `metal` and `nocloud` raw images (spin-only).
- Main branch builds publish OCI images used by matchbox/talm flows.
- If you need Spin + Tailscale on bare metal, boot/install from the spin-tailscale Talos OCI tag.
