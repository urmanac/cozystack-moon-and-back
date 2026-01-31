# =============================================================================
# Chaos Engineering Variables - Sunkworks Episode Scenarios
# =============================================================================

variable "aws_region" {
  description = "AWS region for chaos testing"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (success/failure/chaos)"
  type        = string
  default     = "chaos"
}

variable "episode_name" {
  description = "Sunkworks episode identifier for tagging"
  type        = string
  default     = "sunkworks-pilot"
}

# =============================================================================
# Stress Test Configuration
# =============================================================================

variable "stress_duration_seconds" {
  description = "Duration of CPU/memory stress test in seconds"
  type        = number
  default     = 300 # 5 minutes
}

variable "stress_cpu_percent" {
  description = "CPU stress percentage (t4g.micro has limited burst credits)"
  type        = number
  default     = 80
}

# =============================================================================
# Network Partition Configuration
# =============================================================================

variable "network_partition_minutes" {
  description = "Duration of network partition in minutes"
  type        = number
  default     = 5
}

variable "tailscale_cidr_ranges" {
  description = "Tailscale CIDR ranges to block for partition simulation"
  type        = list(string)
  default     = ["100.64.0.0/10"] # Tailscale CGNAT range
}

# =============================================================================
# EBS Failure Configuration (Ship Going Down Scenario)
# =============================================================================

variable "ebs_pause_seconds" {
  description = "Duration to pause EBS I/O (etcd disaster simulation)"
  type        = number
  default     = 30
}

# =============================================================================
# RTO/Recovery Configuration
# =============================================================================

variable "rto_threshold_seconds" {
  description = "Maximum acceptable recovery time in seconds (10 minutes default)"
  type        = number
  default     = 600 # 10 minutes
}

variable "chaos_duration_seconds" {
  description = "How long to wait after injecting chaos before checking recovery"
  type        = number
  default     = 120
}

# =============================================================================
# Talos/CozyStack Configuration
# =============================================================================

variable "talos_endpoint" {
  description = "Talos API endpoint for health checks"
  type        = string
  default     = ""
}

variable "rollback_snapshot_id" {
  description = "EBS snapshot ID for rollback (known-good state)"
  type        = string
  default     = ""
}

# =============================================================================
# Notification Configuration
# =============================================================================

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for chaos test notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Episode Scenario Presets
# =============================================================================

variable "scenario" {
  description = "Sunkworks episode scenario preset (success/failure/chaos)"
  type        = string
  default     = "chaos"

  validation {
    condition     = contains(["success", "failure", "chaos"], var.scenario)
    error_message = "Scenario must be 'success', 'failure', or 'chaos'."
  }
}

# Scenario-specific defaults
locals {
  scenario_configs = {
    success = {
      stress_duration_seconds = 60
      stress_cpu_percent      = 30
      ebs_pause_seconds       = 5
      rto_threshold_seconds   = 300
    }
    failure = {
      stress_duration_seconds = 600
      stress_cpu_percent      = 100
      ebs_pause_seconds       = 120
      rto_threshold_seconds   = 1800
    }
    chaos = {
      stress_duration_seconds = 300
      stress_cpu_percent      = 80
      ebs_pause_seconds       = 30
      rto_threshold_seconds   = 600
    }
  }
}
