# =============================================================================
# Talos Machine Configuration Template - Raspberry Pi CM5
# =============================================================================
# CM5 offers improved performance vs CM4:
# - Better memory controller efficiency
# - Improved CPU (Cortex-A76)
# - Native PCIe support
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
        mtu: 1500
  
  # CM5 can handle slightly more aggressive settings
  kubelet:
    extraArgs:
      system-reserved: memory=${system_reserved_memory}
      kube-reserved: memory=${kubelet_reserved_memory}
      eviction-hard: memory.available<${eviction_hard_memory}
      eviction-soft: memory.available<150Mi
      eviction-soft-grace-period: memory.available=30s
      # CPU management - CM5's A76 cores handle this well
      cpu-manager-policy: static
      topology-manager-policy: best-effort
      # Enable image credential provider
      image-credential-provider-bin-dir: /usr/local/bin
    extraMounts:
      - destination: /var/lib/containerd
        type: bind
        source: /var/lib/containerd
        options:
          - bind
          - rshared
          - rw
  
  # Install configuration - CM5 boots faster
  install:
    disk: /dev/nvme0n1
    image: ghcr.io/siderolabs/installer:v1.7.0
    bootloader: true
    wipe: false
    # CM5 supports UEFI boot mode properly
    legacyBIOSSupport: false
    extensions:
      - image: ghcr.io/siderolabs/spin:v0.15.1
      - image: ghcr.io/siderolabs/tailscale:1.68.1
  
  # Disk configuration - CM5's PCIe is true Gen2
  disks:
    - device: /dev/nvme0n1
      partitions:
        - mountpoint: /var/lib/etcd
          size: 4GB  # Can afford more on CM5
        - mountpoint: /var/lib/containerd
          size: 0
  
  # Sysctls optimized for CM5
  sysctls:
    vm.overcommit_memory: "1"
    vm.panic_on_oom: "0"
    vm.swappiness: "0"
    # CM5 handles memory pressure better
    vm.vfs_cache_pressure: "50"
    kernel.panic: "10"
    kernel.panic_on_oops: "1"
    # Network optimizations for CM5's improved networking
    net.core.somaxconn: "32768"
    net.ipv4.tcp_max_syn_backlog: "32768"
  
  # Kernel modules
  kernel:
    modules:
      - name: br_netfilter
      - name: overlay
      - name: ip_tables
      - name: iptable_nat
      - name: iptable_mangle
  
  # Time configuration
  time:
    servers:
      - time.cloudflare.com
      - pool.ntp.org
  
  # CM5 features
  features:
    rbac: true
    # Can enable KubePrism on CM5 due to better efficiency
    kubePrism:
      enabled: true
      port: 7445
    # Enable stable hostnames
    stableHostname: true

cluster:
  id: ${cluster_name}
  secret: ""
  
  controlPlane:
    endpoint: ${cluster_endpoint}
  
  clusterName: ${cluster_name}
  
  network:
    cni:
      name: none
    dnsDomain: cluster.local
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12
  
%{ if node_role == "controlplane" ~}
  # etcd - CM5 can handle more
  etcd:
    extraArgs:
      quota-backend-bytes: "4294967296"  # 4GB
      auto-compaction-mode: periodic
      auto-compaction-retention: "1h"
      snapshot-count: "10000"
    # CM5's better I/O allows for advertised client URLs
    advertisedSubnets:
      - 10.0.0.0/8
%{ endif ~}
  
  # API Server configuration
  apiServer:
    extraArgs:
      # CM5 can handle more concurrent requests
      max-requests-inflight: "200"
      max-mutating-requests-inflight: "100"
  
  scheduler:
    extraArgs:
      leader-elect: "true"
  
  discovery:
    enabled: false
  
  # Admission plugins
  adminKubeconfig:
    certLifetime: 8760h  # 1 year

metadata:
  environment: sunkworks
  hardware: turingpi2
  slot: "${node_slot}"
  module: cm5
  memory_mb: ${memory_limit_mb}
