# =============================================================================
# Sunkworks Episode: SUCCESS Scenario
# =============================================================================
# The demo works! CozySummit scenario - everything goes according to plan
# Light chaos, quick recovery, happy audience
# =============================================================================

environment = "success"
episode_name = "cozysummit-demo"
scenario     = "success"

# Light stress testing - don't break the demo
stress_duration_seconds = 60
stress_cpu_percent      = 30

# Brief network blip - recovers quickly
network_partition_minutes = 1

# Minimal EBS disruption - etcd handles it gracefully
ebs_pause_seconds = 5

# Aggressive RTO - we expect fast recovery
rto_threshold_seconds = 300  # 5 minutes

# Short chaos window
chaos_duration_seconds = 30
