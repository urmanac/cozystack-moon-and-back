# =============================================================================
# Stakpak Integration Variables
# =============================================================================

variable "stakpak_namespace" {
  description = "Kubernetes namespace for Stakpak resources"
  type        = string
  default     = "stakpak-system"
}

# =============================================================================
# Source Configuration
# =============================================================================

variable "talos_extensions_ref" {
  description = "Git ref for Talos extensions repository"
  type        = string
  default     = "main"
}

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.7.0"
}

variable "spin_version" {
  description = "Spin containerd shim version"
  type        = string
  default     = "v0.15.1"
}

variable "tailscale_version" {
  description = "Tailscale version"
  type        = string
  default     = "1.68.1"
}

# =============================================================================
# Build Configuration
# =============================================================================

variable "build_platforms" {
  description = "Target platforms for multi-arch builds"
  type        = list(string)
  default     = ["linux/arm64", "linux/amd64"]
}

variable "oci_registry" {
  description = "OCI registry for artifacts"
  type        = string
  default     = "ghcr.io"
}

variable "oci_registry_prefix" {
  description = "OCI registry path prefix"
  type        = string
  default     = "sunkworks/talos-extensions"
}

# =============================================================================
# GitOps Configuration
# =============================================================================

variable "deployment_repo_url" {
  description = "Git repository URL for deployment configs"
  type        = string
}

variable "deployment_branch" {
  description = "Git branch for deployment"
  type        = string
  default     = "main"
}

variable "cluster_name" {
  description = "Target cluster name"
  type        = string
  default     = "sunkworks-demo"
}

# =============================================================================
# Notification Configuration
# =============================================================================

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "pagerduty_routing_key" {
  description = "PagerDuty routing key for critical alerts"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Rollback Configuration
# =============================================================================

variable "rollback_retention_count" {
  description = "Number of known-good states to retain"
  type        = number
  default     = 5
}

variable "stability_period" {
  description = "Time before promoting a deployment to known-good"
  type        = string
  default     = "24h"
}

variable "deployment_timeout" {
  description = "Maximum time to wait for deployment completion"
  type        = string
  default     = "15m"
}
