# =============================================================================
# Sunkworks Episode: CHAOS (Maximum Entropy)
# =============================================================================
# True chaos engineering - systematic failure injection.
# Unpredictable outcomes, validated recovery, educational content.
# "!sinktheship" - anything can happen.
# =============================================================================

# Episode identity
episode_name = "sunkworks-chaos"
environment  = "chaos"
scenario     = "chaos"

# Module enablement - full stack
enable_chaos_engineering = true
enable_turing_pi         = false  # Focus on AWS for controlled chaos
enable_stakpak           = true
enable_live_stream       = true

# Chaos configuration - balanced but unpredictable
chaos_stress_duration   = 300    # 5 minutes
chaos_stress_cpu        = 80     # Leave some headroom
chaos_network_partition = 5      # Meaningful but survivable
chaos_ebs_pause         = 30     # Test etcd resilience
rto_threshold           = 600    # 10 minutes - our stated goal

# The actual chaos tests that will run:
# - Random instance termination (!sinktheship)
# - Network partition simulation (Tailscale failure)
# - EBS I/O pause during etcd writes
# - CPU stress on t4g.micro (free tier limits!)
# - Combined failure modes (the fun part)

# Cost thresholds - standard drama
cost_warning_threshold = 5.0     # Yellow alert
cost_danger_threshold  = 10.0    # Red alert
cost_drama_threshold   = 15.0    # MAXIMUM DRAMA

# Stakpak - stable but current
talos_extensions_ref = "v1.7.0"
spin_version         = "v0.15.1"
tailscale_version    = "1.68.1"

# Build for ARM64 primarily
build_platforms = ["linux/arm64"]

# Stream config with chat commands enabled
twitch_channels = ["sunkworks"]

# Chat command availability:
# !sinktheship - Moderators only, triggers full chaos
# !networkblip - Subscribers, network partition
# !stresstest  - Subscribers, CPU stress
# !status      - Everyone, cluster health check
# !rollback    - Moderators, emergency rollback
# !costs       - Everyone, AWS burn rate
# !drama       - Everyone, drama meter
