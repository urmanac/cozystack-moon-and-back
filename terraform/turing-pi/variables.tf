# =============================================================================
# Turing Pi Variables
# =============================================================================

variable "turingpi_bmc_host" {
  description = "Turing Pi BMC hostname or IP"
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
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "sunkworks-turing"
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  type        = string
  default     = "https://turingpi.local:6443"
}

# =============================================================================
# Node Slot Configuration
# =============================================================================

variable "node_slots" {
  description = "Configuration for each Turing Pi node slot (1-4)"
  type = map(object({
    name         = string
    enabled      = bool
    module_type  = string  # cm4, cm5, jetson
    memory_mb    = number
    role         = string  # controlplane, worker
    nvme_enabled = bool
    talos_image  = string
  }))
  
  default = {
    "1" = {
      name         = "node-1"
      enabled      = true
      module_type  = "cm4"
      memory_mb    = 4096
      role         = "controlplane"
      nvme_enabled = true
      talos_image  = ""
    }
    "2" = {
      name         = "node-2"
      enabled      = true
      module_type  = "cm4"
      memory_mb    = 4096
      role         = "worker"
      nvme_enabled = true
      talos_image  = ""
    }
    "3" = {
      name         = "node-3"
      enabled      = true
      module_type  = "cm4"
      memory_mb    = 4096
      role         = "worker"
      nvme_enabled = true
      talos_image  = ""
    }
    "4" = {
      name         = "node-4"
      enabled      = false
      module_type  = "cm4"
      memory_mb    = 4096
      role         = "worker"
      nvme_enabled = false
      talos_image  = ""
    }
  }
}

# =============================================================================
# Power Monitoring
# =============================================================================

variable "power_monitor_enabled" {
  description = "Enable power consumption monitoring via smart plug"
  type        = bool
  default     = false
}

variable "power_monitor_url" {
  description = "Smart plug API URL (Shelly, TP-Link, etc.)"
  type        = string
  default     = "http://10.0.0.100"
}

variable "measured_power_watts" {
  description = "Measured power consumption in watts (0 = use estimate)"
  type        = number
  default     = 0
}

# =============================================================================
# Cost Analysis Parameters
# =============================================================================

variable "electricity_cost_per_kwh" {
  description = "Electricity cost per kWh in USD"
  type        = number
  default     = 0.12  # US average
}

variable "aws_free_tier_months_remaining" {
  description = "Months remaining on AWS free tier (0-12)"
  type        = number
  default     = 0
}

# =============================================================================
# Talos Configuration
# =============================================================================

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.7.0"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.30.0"
}

variable "talos_extensions" {
  description = "List of Talos extensions to include"
  type        = list(string)
  default     = [
    "siderolabs/spin",
    "siderolabs/tailscale"
  ]
}
