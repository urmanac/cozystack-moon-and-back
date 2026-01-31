# =============================================================================
# Sunkworks Episode: FAILURE (The Typical Experience)
# =============================================================================
# The authentic Sunkworks experience - things go wrong.
# Heavy chaos, extended recovery, maximum drama.
# "Ship Going Down" mode activated.
# =============================================================================

# Episode identity
episode_name = "sunkworks-failure"
environment  = "production"  # Test in prod, Sunkworks style
scenario     = "failure"

# Module enablement - everything for maximum failure surface
enable_chaos_engineering = true
enable_turing_pi         = true   # Hardware adds failure modes
enable_stakpak           = true
enable_live_stream       = true

# Chaos configuration - aggressive
chaos_stress_duration   = 600    # 10 minutes of pain
chaos_stress_cpu        = 100    # Max stress
chaos_network_partition = 10     # Extended network outage
chaos_ebs_pause         = 120    # 2 minutes of etcd terror
rto_threshold           = 1800   # 30 minutes (realistic for Sunkworks)

# Turing Pi - resource constrained chaos
turing_pi_node_slots = {
  "1" = {
    name         = "tpi-node-1"
    enabled      = true
    module_type  = "cm4"
    memory_mb    = 4096
    role         = "controlplane"
    nvme_enabled = true
    talos_image  = "https://factory.talos.dev/..."
  }
  "2" = {
    name         = "tpi-node-2"
    enabled      = true
    module_type  = "cm4"
    memory_mb    = 4096
    role         = "worker"
    nvme_enabled = true
    talos_image  = ""
  }
  "3" = {
    name         = "tpi-node-3"
    enabled      = true
    module_type  = "cm4"
    memory_mb    = 4096
    role         = "worker"
    nvme_enabled = true
    talos_image  = ""
  }
  "4" = {
    name         = "tpi-node-4"
    enabled      = false  # Empty slot for drama
    module_type  = "cm4"
    memory_mb    = 0
    role         = "none"
    nvme_enabled = false
    talos_image  = ""
  }
}

# Power monitoring - watch the meter spin
power_monitor_enabled = true
power_monitor_url     = "http://10.0.0.100"  # Shelly plug

# Cost thresholds - dramatic
cost_warning_threshold = 1.0    # Start worrying early
cost_danger_threshold  = 5.0    # Danger zone
cost_drama_threshold   = 15.0   # THE $15/MONTH NIGHTMARE

# Stakpak - bleeding edge for maximum instability
talos_extensions_ref = "main"    # Living on the edge
spin_version         = "latest"
tailscale_version    = "unstable"

# Stream config
twitch_channels = ["sunkworks"]
