# =============================================================================
# Sunkworks Root Module Variables
# =============================================================================

# =============================================================================
# Environment Configuration
# =============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "sunkworks"
}

variable "episode_name" {
  description = "Sunkworks episode identifier"
  type        = string
  default     = "pilot"
}

variable "scenario" {
  description = "Episode scenario (success/failure/chaos)"
  type        = string
  default     = "chaos"
}

variable "timezone" {
  description = "Timezone for timestamps"
  type        = string
  default     = "America/New_York"
}

# =============================================================================
# Module Enablement Flags
# =============================================================================

variable "enable_chaos_engineering" {
  description = "Enable chaos engineering module"
  type        = bool
  default     = true
}

variable "enable_turing_pi" {
  description = "Enable Turing Pi hardware module"
  type        = bool
  default     = false
}

variable "enable_stakpak" {
  description = "Enable Stakpak integration module"
  type        = bool
  default     = true
}

variable "enable_live_stream" {
  description = "Enable live stream infrastructure module"
  type        = bool
  default     = true
}

# =============================================================================
# Chaos Engineering Variables
# =============================================================================

variable "chaos_stress_duration" {
  description = "Duration of stress tests in seconds"
  type        = number
  default     = 300
}

variable "chaos_stress_cpu" {
  description = "CPU stress percentage"
  type        = number
  default     = 80
}

variable "chaos_network_partition" {
  description = "Network partition duration in minutes"
  type        = number
  default     = 5
}

variable "chaos_ebs_pause" {
  description = "EBS I/O pause duration in seconds"
  type        = number
  default     = 30
}

variable "rto_threshold" {
  description = "Recovery Time Objective threshold in seconds"
  type        = number
  default     = 600
}

variable "talos_endpoint" {
  description = "Talos API endpoint"
  type        = string
  default     = ""
}

variable "rollback_snapshot_id" {
  description = "EBS snapshot ID for rollback"
  type        = string
  default     = ""
}

# =============================================================================
# Turing Pi Variables
# =============================================================================

variable "turingpi_bmc_host" {
  description = "Turing Pi BMC hostname"
  type        = string
  default     = "turingpi.local"
}

variable "turingpi_username" {
  description = "BMC username"
  type        = string
  default     = "root"
}

variable "turingpi_password" {
  description = "BMC password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "turing_pi_node_slots" {
  description = "Turing Pi node slot configuration"
  type = map(object({
    name         = string
    enabled      = bool
    module_type  = string
    memory_mb    = number
    role         = string
    nvme_enabled = bool
    talos_image  = string
  }))
  default = {}
}

variable "power_monitor_enabled" {
  description = "Enable power consumption monitoring"
  type        = bool
  default     = false
}

variable "power_monitor_url" {
  description = "Smart plug API URL"
  type        = string
  default     = ""
}

variable "electricity_cost_per_kwh" {
  description = "Electricity cost per kWh"
  type        = number
  default     = 0.12
}

variable "aws_free_tier_months_remaining" {
  description = "Months remaining on AWS free tier"
  type        = number
  default     = 0
}

# =============================================================================
# Cluster Configuration
# =============================================================================

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "sunkworks-demo"
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  type        = string
  default     = ""
}

# =============================================================================
# Stakpak Variables
# =============================================================================

variable "stakpak_namespace" {
  description = "Stakpak namespace"
  type        = string
  default     = "stakpak-system"
}

variable "talos_extensions_ref" {
  description = "Git ref for Talos extensions"
  type        = string
  default     = "main"
}

variable "talos_version" {
  description = "Talos version"
  type        = string
  default     = "v1.7.0"
}

variable "spin_version" {
  description = "Spin version"
  type        = string
  default     = "v0.15.1"
}

variable "tailscale_version" {
  description = "Tailscale version"
  type        = string
  default     = "1.68.1"
}

variable "build_platforms" {
  description = "Build target platforms"
  type        = list(string)
  default     = ["linux/arm64", "linux/amd64"]
}

variable "oci_registry" {
  description = "OCI registry"
  type        = string
  default     = "ghcr.io"
}

variable "oci_registry_prefix" {
  description = "OCI registry path prefix"
  type        = string
  default     = "sunkworks/extensions"
}

variable "deployment_repo_url" {
  description = "Deployment repository URL"
  type        = string
  default     = ""
}

variable "deployment_branch" {
  description = "Deployment branch"
  type        = string
  default     = "main"
}

# =============================================================================
# Live Stream Variables
# =============================================================================

variable "mqtt_broker_host" {
  description = "MQTT broker hostname"
  type        = string
  default     = "localhost"
}

variable "mqtt_broker_port" {
  description = "MQTT broker port"
  type        = number
  default     = 1883
}

variable "obs_websocket_host" {
  description = "OBS WebSocket host"
  type        = string
  default     = "localhost"
}

variable "obs_websocket_port" {
  description = "OBS WebSocket port"
  type        = number
  default     = 4455
}

variable "obs_websocket_password" {
  description = "OBS WebSocket password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "twitch_bot_username" {
  description = "Twitch bot username"
  type        = string
  default     = "SunkworksBot"
}

variable "twitch_channels" {
  description = "Twitch channels"
  type        = list(string)
  default     = []
}

variable "cost_warning_threshold" {
  description = "Cost warning threshold"
  type        = number
  default     = 5.0
}

variable "cost_danger_threshold" {
  description = "Cost danger threshold"
  type        = number
  default     = 10.0
}

variable "cost_drama_threshold" {
  description = "Cost drama threshold"
  type        = number
  default     = 15.0
}

# =============================================================================
# Notification Variables
# =============================================================================

variable "slack_webhook_url" {
  description = "Slack webhook URL"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs for alarms"
  type        = list(string)
  default     = []
}

variable "pagerduty_routing_key" {
  description = "PagerDuty routing key"
  type        = string
  default     = ""
  sensitive   = true
}
