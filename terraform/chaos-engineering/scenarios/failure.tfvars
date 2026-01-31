# =============================================================================
# Sunkworks Episode: FAILURE Scenario
# =============================================================================
# Things go wrong! The typical Sunkworks experience.
# Heavy chaos, extended recovery times, dramatic tension
# "Ship going down" mode activated
# =============================================================================

environment = "failure"
episode_name = "sunkworks-typical"
scenario     = "failure"

# Maximum stress - push t4g.micro to its limits
stress_duration_seconds = 600  # 10 minutes of pain
stress_cpu_percent      = 100  # Full throttle

# Extended network partition - Tailscale goes dark
network_partition_minutes = 10

# Serious EBS failure - the "ship going down" experience
ebs_pause_seconds = 120  # 2 minutes of etcd horror

# Relaxed RTO - we expect extended downtime
rto_threshold_seconds = 1800  # 30 minutes (Sunkworks reality)

# Extended chaos window - let it cook
chaos_duration_seconds = 300
