# =============================================================================
# Talos Machine Configuration Template - Raspberry Pi CM4
# =============================================================================
# Optimized for 4GB RAM constraint on Turing Pi 2
# Memory management is critical for CozyStack workloads
# =============================================================================

version: v1alpha1
debug: false
persist: true

machine:
  type: ${node_role}
  network:
    hostname: ${node_name}
    interfaces:
      - interface: eth0
        dhcp: true
        # Turing Pi 2 uses internal network
        mtu: 1500
  
  # Resource constraints for 4GB CM4
  kubelet:
    extraArgs:
      # Memory management for constrained nodes
      system-reserved: memory=${system_reserved_memory}
      kube-reserved: memory=${kubelet_reserved_memory}
      eviction-hard: memory.available<${eviction_hard_memory}
      eviction-soft: memory.available<200Mi
      eviction-soft-grace-period: memory.available=30s
      # CPU management
      cpu-manager-policy: static
      topology-manager-policy: best-effort
    extraMounts:
      - destination: /var/lib/containerd
        type: bind
        source: /var/lib/containerd
        options:
          - bind
          - rshared
          - rw
  
  # Install configuration
  install:
    disk: /dev/nvme0n1
    image: ghcr.io/siderolabs/installer:v1.7.0
    bootloader: true
    wipe: false
    extensions:
      - image: ghcr.io/siderolabs/spin:v0.15.1
      - image: ghcr.io/siderolabs/tailscale:1.68.1
  
  # System disk configuration
  disks:
    - device: /dev/nvme0n1
      partitions:
        - mountpoint: /var/lib/etcd
          size: 2GB
        - mountpoint: /var/lib/containerd
          size: 0  # Use remaining space
  
  # Sysctls for memory optimization
  sysctls:
    vm.overcommit_memory: "1"
    vm.panic_on_oom: "0"
    vm.swappiness: "0"
    kernel.panic: "10"
    kernel.panic_on_oops: "1"
  
  # Kernel runtime configuration
  kernel:
    modules:
      - name: br_netfilter
      - name: overlay
  
  # Time configuration
  time:
    servers:
      - time.cloudflare.com
      - pool.ntp.org
  
  # CM4 specific: Disable features to save memory
  features:
    # Disable KubePrism for memory savings on small nodes
    kubePrism:
      enabled: false

cluster:
  id: ${cluster_name}
  secret: ""  # Will be generated
  
  # Control plane configuration
  controlPlane:
    endpoint: ${cluster_endpoint}
  
  clusterName: ${cluster_name}
  
  # Network configuration
  network:
    cni:
      name: none  # CozyStack provides CNI
    dnsDomain: cluster.local
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12
  
%{ if node_role == "controlplane" ~}
  # etcd configuration for constrained memory
  etcd:
    extraArgs:
      # Reduce etcd memory footprint
      quota-backend-bytes: "2147483648"  # 2GB (fits in 4GB node)
      auto-compaction-mode: periodic
      auto-compaction-retention: "1h"
      snapshot-count: "5000"
%{ endif ~}
  
  # Scheduler configuration
  scheduler:
    extraArgs:
      # Profile for resource-constrained nodes
      leader-elect: "true"
  
  # Discovery disabled (static cluster)
  discovery:
    enabled: false

# Node metadata for Turing Pi identification
metadata:
  environment: sunkworks
  hardware: turingpi2
  slot: "${node_slot}"
  module: cm4
  memory_mb: ${memory_limit_mb}
