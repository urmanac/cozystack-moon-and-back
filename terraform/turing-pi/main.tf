# =============================================================================
# Turing Pi Hardware Migration Path
# =============================================================================
# The resource-constrained cluster we didn't get to demo
# Terraform for Turing Pi 2 BMC management
# Cost analysis: AWS t4g.micro vs Turing Pi node ($65 hardware)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    # Turing Pi BMC provider (community/experimental)
    turingpi = {
      source  = "turingpi/turingpi"
      version = "~> 0.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

# =============================================================================
# Turing Pi BMC Configuration
# =============================================================================

provider "turingpi" {
  # BMC endpoint (default is turingpi.local)
  host     = var.turingpi_bmc_host
  username = var.turingpi_username
  password = var.turingpi_password
}

# =============================================================================
# Node Slot Configuration
# =============================================================================

resource "turingpi_node" "compute_nodes" {
  for_each = var.node_slots

  slot        = each.key
  power_state = each.value.enabled ? "on" : "off"
  
  # UART settings for Talos boot
  uart_enabled = true
  
  # Flash Talos image if specified
  dynamic "flash" {
    for_each = each.value.talos_image != "" ? [1] : []
    content {
      image_url = each.value.talos_image
      verify    = true
    }
  }
}

# =============================================================================
# Talos Machine Configuration for CM4/CM5 with 4GB RAM Limits
# =============================================================================

resource "local_file" "talos_config_cm4" {
  for_each = { for k, v in var.node_slots : k => v if v.module_type == "cm4" }

  filename = "${path.module}/generated/talos-node-${each.key}.yaml"
  content  = templatefile("${path.module}/templates/talos-cm4.yaml.tpl", {
    node_slot       = each.key
    node_name       = each.value.name
    node_role       = each.value.role
    cluster_name    = var.cluster_name
    cluster_endpoint = var.cluster_endpoint
    memory_limit_mb = each.value.memory_mb
    # CM4 with 4GB RAM needs careful memory management
    kubelet_reserved_memory = "512Mi"
    system_reserved_memory  = "256Mi"
    eviction_hard_memory    = "100Mi"
  })
}

resource "local_file" "talos_config_cm5" {
  for_each = { for k, v in var.node_slots : k => v if v.module_type == "cm5" }

  filename = "${path.module}/generated/talos-node-${each.key}.yaml"
  content  = templatefile("${path.module}/templates/talos-cm5.yaml.tpl", {
    node_slot       = each.key
    node_name       = each.value.name
    node_role       = each.value.role
    cluster_name    = var.cluster_name
    cluster_endpoint = var.cluster_endpoint
    memory_limit_mb = each.value.memory_mb
    # CM5 has better memory efficiency
    kubelet_reserved_memory = "384Mi"
    system_reserved_memory  = "256Mi"
    eviction_hard_memory    = "100Mi"
  })
}

# =============================================================================
# Power Consumption Monitoring (PDU/Smart Plug Integration)
# =============================================================================

# Shelly smart plug API for power monitoring
data "http" "power_consumption" {
  count = var.power_monitor_enabled ? 1 : 0
  url   = "${var.power_monitor_url}/status"
  
  request_headers = {
    Accept = "application/json"
  }
}

resource "local_file" "power_report" {
  count    = var.power_monitor_enabled ? 1 : 0
  filename = "${path.module}/generated/power-report.json"
  
  content = jsonencode({
    timestamp      = timestamp()
    cluster_name   = var.cluster_name
    total_nodes    = length([for k, v in var.node_slots : k if v.enabled])
    power_watts    = try(jsondecode(data.http.power_consumption[0].response_body).meters[0].power, 0)
    energy_wh      = try(jsondecode(data.http.power_consumption[0].response_body).meters[0].total, 0)
    estimated_monthly_kwh = try(jsondecode(data.http.power_consumption[0].response_body).meters[0].power * 24 * 30 / 1000, 0)
    estimated_monthly_cost = try(jsondecode(data.http.power_consumption[0].response_body).meters[0].power * 24 * 30 / 1000 * var.electricity_cost_per_kwh, 0)
  })
}

# =============================================================================
# Cost Analysis Module: AWS vs Turing Pi
# =============================================================================

locals {
  # AWS t4g.micro costs (free tier eligible for 750 hrs/month for 12 months)
  aws_t4g_micro_hourly = 0.0084  # On-demand price
  aws_free_tier_hours  = 750
  
  # Turing Pi hardware costs
  turingpi_board_cost = 209.00   # Turing Pi 2 board
  cm4_4gb_cost        = 65.00    # Raspberry Pi CM4 4GB
  cm5_4gb_cost        = 75.00    # Raspberry Pi CM5 4GB (estimated)
  nvme_256gb_cost     = 35.00    # NVMe drive per node
  psu_cost            = 30.00    # Power supply
  
  # Operating costs
  turingpi_power_watts     = var.measured_power_watts > 0 ? var.measured_power_watts : 40
  hours_per_month          = 730
  turingpi_monthly_kwh     = local.turingpi_power_watts * local.hours_per_month / 1000
  turingpi_monthly_power   = local.turingpi_monthly_kwh * var.electricity_cost_per_kwh
  
  # Calculate node costs
  node_hardware_costs = {
    for slot, node in var.node_slots : slot => (
      (node.module_type == "cm4" ? local.cm4_4gb_cost : local.cm5_4gb_cost) +
      (node.nvme_enabled ? local.nvme_256gb_cost : 0)
    )
  }
  
  total_hardware_cost = (
    local.turingpi_board_cost +
    local.psu_cost +
    sum([for slot, cost in local.node_hardware_costs : cost if var.node_slots[slot].enabled])
  )
  
  # AWS comparison
  active_nodes = length([for k, v in var.node_slots : k if v.enabled])
  
  aws_monthly_cost_post_free_tier = local.active_nodes * local.aws_t4g_micro_hourly * local.hours_per_month
  aws_monthly_cost_free_tier      = local.active_nodes > 1 ? (local.active_nodes - 1) * local.aws_t4g_micro_hourly * (local.hours_per_month - local.aws_free_tier_hours / local.active_nodes) : 0
  
  # Break-even analysis
  monthly_savings = local.aws_monthly_cost_post_free_tier - local.turingpi_monthly_power
  breakeven_months = local.monthly_savings > 0 ? ceil(local.total_hardware_cost / local.monthly_savings) : -1
}

# Cost comparison output
resource "local_file" "cost_analysis" {
  filename = "${path.module}/generated/cost-analysis.json"
  
  content = jsonencode({
    analysis_date = timestamp()
    cluster_config = {
      name         = var.cluster_name
      active_nodes = local.active_nodes
      node_types   = { for k, v in var.node_slots : v.name => v.module_type if v.enabled }
    }
    
    hardware_costs = {
      turingpi_board = local.turingpi_board_cost
      power_supply   = local.psu_cost
      nodes          = local.node_hardware_costs
      total          = local.total_hardware_cost
    }
    
    monthly_operating_costs = {
      turingpi = {
        power_watts      = local.turingpi_power_watts
        kwh_per_month    = local.turingpi_monthly_kwh
        electricity_rate = var.electricity_cost_per_kwh
        cost             = local.turingpi_monthly_power
      }
      aws = {
        free_tier_eligible = var.aws_free_tier_months_remaining > 0
        hourly_rate        = local.aws_t4g_micro_hourly
        cost_with_free_tier    = local.aws_monthly_cost_free_tier
        cost_post_free_tier    = local.aws_monthly_cost_post_free_tier
        cost_estimate = var.aws_free_tier_months_remaining > 0 ? local.aws_monthly_cost_free_tier : local.aws_monthly_cost_post_free_tier
      }
    }
    
    comparison = {
      monthly_savings_vs_aws    = local.monthly_savings
      breakeven_months          = local.breakeven_months
      yearly_savings            = local.monthly_savings * 12
      recommendation            = local.breakeven_months > 0 && local.breakeven_months < 24 ? "hardware" : "cloud"
      note = local.breakeven_months < 0 ? "Turing Pi costs more than AWS at current electricity rates" : "Break-even in ${local.breakeven_months} months"
    }
    
    # The "$0.04/month → $15/month" drama context
    sunkworks_budget_note = "Unlike the 128°F office space heater scenario, Turing Pi provides consistent power draw"
  })
}

# =============================================================================
# Sunkworks Budget Calculator
# =============================================================================

resource "local_file" "sunkworks_budget" {
  filename = "${path.module}/generated/sunkworks-budget.md"
  
  content = <<-EOT
    # Sunkworks Budget Calculator
    ## When Does Cloud Cost Exceed Hardware + Electricity?

    Generated: ${timestamp()}
    Cluster: ${var.cluster_name}
    
    ## Hardware Investment
    
    | Component | Cost |
    |-----------|------|
    | Turing Pi 2 Board | $${format("%.2f", local.turingpi_board_cost)} |
    | Power Supply | $${format("%.2f", local.psu_cost)} |
    %{for slot, node in var.node_slots~}
    %{if node.enabled~}
    | ${node.name} (${node.module_type}) | $${format("%.2f", local.node_hardware_costs[slot])} |
    %{endif~}
    %{endfor~}
    | **Total Hardware** | **$${format("%.2f", local.total_hardware_cost)}** |
    
    ## Monthly Operating Costs
    
    ### Turing Pi Cluster
    - Power consumption: ${local.turingpi_power_watts}W
    - Monthly kWh: ${format("%.1f", local.turingpi_monthly_kwh)}
    - Electricity rate: $${format("%.2f", var.electricity_cost_per_kwh)}/kWh
    - **Monthly cost: $${format("%.2f", local.turingpi_monthly_power)}**
    
    ### AWS Equivalent (${local.active_nodes}x t4g.micro)
    - Free tier remaining: ${var.aws_free_tier_months_remaining} months
    - Hourly rate: $${format("%.4f", local.aws_t4g_micro_hourly)} per instance
    - **Monthly cost (post free-tier): $${format("%.2f", local.aws_monthly_cost_post_free_tier)}**
    
    ## Break-Even Analysis
    
    %{if local.breakeven_months > 0~}
    - Monthly savings vs AWS: $${format("%.2f", local.monthly_savings)}
    - Break-even point: **${local.breakeven_months} months**
    - Yearly savings after break-even: $${format("%.2f", local.monthly_savings * 12)}
    
    ### Recommendation: %{if local.breakeven_months < 24}✅ Hardware Worth It%{else}☁️ Stick with Cloud%{endif}
    %{else~}
    ⚠️ At current electricity rates, Turing Pi costs more than AWS.
    Consider regions with lower electricity costs or solar power.
    %{endif~}
    
    ## The Drama Factor
    
    > From "$0.04/month → $15/month" - Sunkworks Episode 1
    
    The free tier cliff is real. Plan accordingly.
    
    ---
    *Unlike the 128°F office space heater scenario, Turing Pi provides 
    predictable, consistent power draw. Your A/C will thank you.*
  EOT
}

# =============================================================================
# Outputs
# =============================================================================

output "node_configurations" {
  description = "Generated Talos configurations for each node"
  value = {
    cm4_nodes = [for k, v in local_file.talos_config_cm4 : v.filename]
    cm5_nodes = [for k, v in local_file.talos_config_cm5 : v.filename]
  }
}

output "cost_analysis" {
  description = "Cost comparison between Turing Pi and AWS"
  value = {
    hardware_cost         = local.total_hardware_cost
    monthly_power_cost    = local.turingpi_monthly_power
    aws_monthly_cost      = local.aws_monthly_cost_post_free_tier
    breakeven_months      = local.breakeven_months
    recommendation        = local.breakeven_months > 0 && local.breakeven_months < 24 ? "hardware" : "cloud"
  }
}

output "power_consumption" {
  description = "Current power consumption metrics"
  value = var.power_monitor_enabled ? {
    current_watts = try(jsondecode(data.http.power_consumption[0].response_body).meters[0].power, "unknown")
    total_wh      = try(jsondecode(data.http.power_consumption[0].response_body).meters[0].total, "unknown")
  } : {
    current_watts = "monitoring disabled"
    total_wh      = "monitoring disabled"
  }
}
