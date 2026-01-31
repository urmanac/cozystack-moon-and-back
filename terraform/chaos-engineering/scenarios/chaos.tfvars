# =============================================================================
# Sunkworks Episode: CHAOS Scenario
# =============================================================================
# Maximum entropy - the full chaos engineering experience
# Random failures, unpredictable recovery, audience on edge
# "!sinktheship" mode - anything can happen
# =============================================================================

environment = "chaos"
episode_name = "sunkworks-chaos"
scenario     = "chaos"

# Moderate but sustained stress
stress_duration_seconds = 300  # 5 minutes
stress_cpu_percent      = 80   # Leave some headroom for chaos

# Unpredictable network behavior
network_partition_minutes = 5

# Significant EBS disruption - but survivable
ebs_pause_seconds = 30

# Standard RTO target - we're validating recovery capability
rto_threshold_seconds = 600  # 10 minutes (our stated goal)

# Moderate chaos window
chaos_duration_seconds = 120

# Additional chaos-specific settings
# (These would be used by the Step Functions orchestrator)
