# Matchbox Server Configuration for Custom Talos Images

## Overview

This document describes how the AWS bastion's matchbox server will serve custom ARM64 Talos images for netbooting. The configuration integrates with the CozyStack ARM64 images built via GitHub Actions and stored in GHCR.

## Architecture

```
Talos Node Boot Process:
1. t4g.small instance launches (AWS EC2)
2. PXE boot → DHCP request (dnsmasq on bastion)
3. DHCP response → next-server: 10.20.13.140 (matchbox)
4. TFTP/HTTP → matchbox serves ARM64 kernel/initramfs
5. Talos boots with Spin + Tailscale extensions
6. Node joins CozyStack cluster
```

## Bastion Matchbox Setup

### Directory Structure
```
/opt/matchbox/
├── assets/
│   └── talos/
│       └── arm64/           # ← Custom ARM64 assets from GHCR
│           ├── vmlinuz      # ARM64 kernel
│           ├── initramfs.xz # ARM64 initramfs with extensions
│           ├── vmlinuz.sha256
│           └── initramfs.xz.sha256
├── profiles/
│   └── cozystack-arm64.json # Talos boot profile
├── groups/
│   └── default.json         # Machine group assignment
└── ignition/
    └── cozystack-config.yaml # Talos machine config
```

### Asset Extraction from GHCR

The bastion pulls custom Talos assets from the GitHub Container Registry during startup:

```bash
#!/bin/bash
# /opt/bastion-setup/extract-talos-assets.sh

set -e

# Pull the latest custom Talos image
echo "Pulling custom Talos ARM64 image from GHCR..."
docker pull ghcr.io/urmanac/talos-cozystack-demo:demo-stable

# Extract boot assets to matchbox
echo "Extracting ARM64 boot assets..."
mkdir -p /opt/matchbox/assets/talos/arm64
docker run --rm \
  -v /opt/matchbox/assets:/output \
  ghcr.io/urmanac/talos-cozystack-demo:demo-stable \
  /output/talos/arm64/

# Verify assets extracted correctly
echo "Verifying ARM64 assets..."
ls -la /opt/matchbox/assets/talos/arm64/
sha256sum -c /opt/matchbox/assets/talos/arm64/*.sha256

# Set appropriate permissions
chown -R matchbox:matchbox /opt/matchbox/assets/
chmod -R 644 /opt/matchbox/assets/talos/arm64/*

echo "✅ Custom ARM64 Talos assets ready for netboot"
```

### Matchbox Profile Configuration

```json
{
  "id": "cozystack-arm64",
  "name": "CozyStack ARM64 with Spin + Tailscale",
  "boot": {
    "kernel": "/assets/talos/arm64/vmlinuz",
    "initrd": ["/assets/talos/arm64/initramfs.xz"],
    "args": [
      "init_on_alloc=1",
      "init_on_free=1",
      "slub_debug=P",
      "pti=on",
      "console=tty0",
      "console=ttyS0",
      "printk.devkmsg=on",
      "talos.platform=metal",
      "talos.config=http://10.20.13.140:8080/ignition?uuid=${uuid}"
    ]
  }
}
```

### Machine Group Assignment

```json
{
  "id": "default",
  "name": "Default ARM64 CozyStack Nodes", 
  "profile": "cozystack-arm64",
  "selector": {
    "arch": "arm64"
  },
  "metadata": {
    "cozystack_cluster": "demo",
    "extensions_enabled": ["spin", "tailscale"]
  }
}
```

### Talos Machine Configuration

```yaml
# /opt/matchbox/ignition/cozystack-config.yaml
version: v1alpha1
debug: false
persist: true

machine:
  type: worker  # or controlplane for first node
  token: <cluster-join-token>
  ca:
    crt: <cluster-ca-certificate>
  certSANs:
    - 10.20.13.140
    - cluster.local
  
  kubelet:
    image: ghcr.io/siderolabs/kubelet:v1.31.0
    defaultRuntimeSeccompProfileEnabled: true
    registerWithTaints:
      - node.cozystack.io/arm64:NoSchedule

  network:
    hostname: talos-demo-${uuid}
    interfaces:
      - interface: eth0
        dhcp: true
        vlans:
          - vlanId: 13
            dhcp: true

  install:
    disk: /dev/nvme0n1  # Typical for t4g instances
    image: ghcr.io/urmanac/talos-cozystack-demo:demo-stable
    wipe: false

cluster:
  id: <cluster-id>
  secret: <cluster-secret>
  controlPlane:
    endpoint: https://10.20.13.100:6443  # First node IP
  clusterName: cozystack-demo
  network:
    dnsDomain: cluster.local
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12
  token: <bootstrap-token>
  ca:
    crt: <cluster-ca-cert>
    key: <cluster-ca-key>
```

## Docker Compose Integration

The bastion runs matchbox as part of its Docker infrastructure:

```yaml
# /opt/bastion-setup/docker-compose.yml (excerpt)

services:
  matchbox:
    image: quay.io/poseidon/matchbox:v0.11.0
    container_name: matchbox
    restart: unless-stopped
    ports:
      - "8080:8080"  # HTTP API
      - "8081:8081"  # gRPC API  
    volumes:
      - /opt/matchbox:/var/lib/matchbox:Z
      - /opt/matchbox/assets:/var/lib/matchbox/assets:Z
    environment:
      MATCHBOX_ADDRESS: "0.0.0.0:8080"
      MATCHBOX_RPC_ADDRESS: "0.0.0.0:8081"
      MATCHBOX_LOG_LEVEL: "debug"
    depends_on:
      - dnsmasq
    networks:
      netboot_net:
        ipv4_address: 10.20.13.140

  dnsmasq:
    image: dnsmasq/dnsmasq:latest
    container_name: dnsmasq
    restart: unless-stopped
    ports:
      - "67:67/udp"   # DHCP
      - "69:69/udp"   # TFTP
    volumes:
      - /opt/bastion-setup/dnsmasq.conf:/etc/dnsmasq.conf:ro
    cap_add:
      - NET_ADMIN
    networks:
      netboot_net:
        ipv4_address: 10.20.13.140

networks:
  netboot_net:
    driver: bridge
    ipam:
      config:
        - subnet: 10.20.13.0/24
```

### dnsmasq Configuration

```bash
# /opt/bastion-setup/dnsmasq.conf

# DHCP Configuration
interface=eth0
bind-interfaces
dhcp-range=10.20.13.150,10.20.13.200,24h
dhcp-option=option:router,10.20.13.1
dhcp-option=option:dns-server,10.20.13.140

# PXE Boot Configuration  
enable-tftp
tftp-root=/var/lib/matchbox/assets
dhcp-userclass=set:ipxe,iPXE
dhcp-boot=tag:#ipxe,undionly.kpxe
dhcp-boot=tag:ipxe,http://10.20.13.140:8080/boot.ipxe

# ARM64 specific settings
dhcp-match=set:efibc,option:client-arch,7  # EFI BC (ARM64)
dhcp-boot=tag:efibc,tag:!ipxe,bootaa64.efi
dhcp-boot=tag:efibc,tag:ipxe,http://10.20.13.140:8080/boot.ipxe

# Logging
log-dhcp
log-queries
```

## Flux ExternalArtifact Integration (Future)

For advanced GitOps workflows with Flux 2.7+, we can reference the custom Talos images as external artifacts:

```yaml
# flux-external-artifacts/talos-custom-images.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: ExternalSource
metadata:
  name: talos-cozystack-custom
  namespace: flux-system
spec:
  url: oci://ghcr.io/urmanac/talos-cozystack-demo
  tag: demo-stable
  layer: 
    mediaType: application/vnd.oci.image.layer.v1.tar
    # Extract specific assets for different use cases
  interval: 1h
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization 
metadata:
  name: talos-image-updates
  namespace: flux-system
spec:
  interval: 1h
  sourceRef:
    kind: ExternalSource
    name: talos-cozystack-custom
  path: "./assets"
  prune: true
  targetNamespace: cozy-system
  postBuild:
    substitute:
      TALOS_VERSION: "${TALOS_VERSION}"
      KERNEL_DIGEST: "${KERNEL_DIGEST}"
      INITRAMFS_DIGEST: "${INITRAMFS_DIGEST}"
```

## Validation & Testing

### Test 1: Asset Extraction
```bash
#!/bin/bash
# tests/matchbox/01-asset-extraction.sh

test_ghcr_image_pullable() {
  docker pull ghcr.io/urmanac/talos-cozystack-demo:demo-stable
}

test_assets_extract_correctly() {
  mkdir -p /tmp/test-assets
  docker run --rm -v /tmp/test-assets:/output \
    ghcr.io/urmanac/talos-cozystack-demo:demo-stable \
    /output/talos/arm64/
  
  test -f /tmp/test-assets/talos/arm64/vmlinuz
  test -f /tmp/test-assets/talos/arm64/initramfs.xz
  sha256sum -c /tmp/test-assets/talos/arm64/*.sha256
}
```

### Test 2: Matchbox HTTP API
```bash
#!/bin/bash
# tests/matchbox/02-matchbox-api.sh

test_matchbox_serves_assets() {
  # Test that matchbox HTTP API serves ARM64 assets
  curl -f http://10.20.13.140:8080/assets/talos/arm64/vmlinuz > /dev/null
  curl -f http://10.20.13.140:8080/assets/talos/arm64/initramfs.xz > /dev/null
}

test_matchbox_boot_profile() {
  # Test that matchbox returns correct boot profile
  PROFILE=$(curl -s http://10.20.13.140:8080/profiles/cozystack-arm64)
  echo "$PROFILE" | jq -e '.boot.kernel == "/assets/talos/arm64/vmlinuz"'
  echo "$PROFILE" | jq -e '.boot.initrd[0] == "/assets/talos/arm64/initramfs.xz"'
}
```

### Test 3: End-to-End Netboot
```bash
#!/bin/bash
# tests/matchbox/03-netboot-e2e.sh

test_talos_node_netboots() {
  # Launch new t4g.small instance, wait for netboot
  # This requires actual AWS integration
  echo "Manual test: Launch t4g.small instance, verify netboot"
  echo "Expected: Node appears in 'talosctl get members' within 5 minutes"
}
```

## Operational Procedures

### Updating Custom Images

1. **Update patches** in `/patches/` directory
2. **Trigger GitHub Actions** build via commit or manual dispatch
3. **Bastion auto-updates** on next startup (or manual trigger):
   ```bash
   ssh ubuntu@10.20.13.140 'sudo /opt/bastion-setup/extract-talos-assets.sh'
   ```
4. **Verify update**:
   ```bash
   curl -s http://10.20.13.140:8080/assets/talos/arm64/vmlinuz.sha256
   ```

### Troubleshooting

**Problem**: Talos nodes not netbooting
- **Check**: dnsmasq DHCP logs: `docker logs dnsmasq`
- **Check**: matchbox asset serving: `curl http://10.20.13.140:8080/assets/talos/arm64/vmlinuz`
- **Check**: EC2 instance launch: PXE boot enabled, correct subnet

**Problem**: Extensions not loading
- **Check**: Custom image built correctly: GitHub Actions logs
- **Check**: Patches applied: `talosctl -n <node> get extensions`
- **Check**: ARM64 compatibility: Extension sources

**Problem**: High AWS costs
- **Monitor**: EC2 instances running longer than expected
- **Alert**: Cost exceeding $0.10/month threshold
- **Action**: Terminate all non-bastion instances

## Cost Optimization

### Free Tier Management
- **GHCR pulls**: Free for public repos (no egress cost)
- **Asset caching**: Store assets locally on bastion (EBS cost only)
- **Bandwidth**: Private VPC networking (no data transfer costs)
- **Compute**: Netboot process uses minimal bastion CPU

### Future Optimizations
- **Lambda matchbox**: Replace Docker container with serverless
- **EFS storage**: Share assets across multiple bastions
- **CloudFront**: Cache assets globally (if needed for multi-region)

---

**Next Documents**: 
- `AWS-INFRASTRUCTURE-HANDOFF.md` - Instructions for AWS-capable Claude agent
- `DEMO-SCRIPT.md` - Step-by-step presentation workflow