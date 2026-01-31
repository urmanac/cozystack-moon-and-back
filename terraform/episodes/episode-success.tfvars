# =============================================================================
# Sunkworks Episode: SUCCESS (CozySummit Demo)
# =============================================================================
# Everything works! The demo everyone hopes for but rarely gets.
# Light chaos, guaranteed recovery, audience goes home happy.
# =============================================================================

# Episode identity
episode_name = "cozysummit-success"
environment  = "demo"
scenario     = "success"

# Module enablement - minimal for clean demo
enable_chaos_engineering = true
enable_turing_pi         = false
enable_stakpak           = true
enable_live_stream       = true

# Chaos configuration - gentle
chaos_stress_duration   = 60    # 1 minute stress
chaos_stress_cpu        = 30    # Light load
chaos_network_partition = 1     # Brief blip
chaos_ebs_pause         = 5     # Minimal disk pause
rto_threshold           = 300   # 5 minute recovery acceptable

# Cost thresholds - optimistic
cost_warning_threshold = 10.0   # Higher threshold for demo
cost_danger_threshold  = 20.0
cost_drama_threshold   = 50.0   # Won't hit this in a demo

# Stakpak - stable versions
talos_extensions_ref = "v1.7.0"  # Pinned tag, not main
spin_version         = "v0.15.1"
tailscale_version    = "1.68.1"

# Stream config
twitch_channels = ["cozysummit"]
