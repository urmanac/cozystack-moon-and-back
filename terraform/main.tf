# =============================================================================
# Sunkworks Terraform Root Module
# =============================================================================
# Orchestrates all infrastructure modules for different episode scenarios
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  
  backend "s3" {
    bucket = "sunkworks-terraform-state"
    key    = "sunkworks/terraform.tfstate"
    region = "us-east-1"
  }
}

# =============================================================================
# Module: Chaos Engineering
# =============================================================================

module "chaos_engineering" {
  source = "./chaos-engineering"
  
  count = var.enable_chaos_engineering ? 1 : 0
  
  aws_region              = var.aws_region
  environment             = var.environment
  episode_name            = var.episode_name
  scenario                = var.scenario
  
  stress_duration_seconds   = var.chaos_stress_duration
  stress_cpu_percent        = var.chaos_stress_cpu
  network_partition_minutes = var.chaos_network_partition
  ebs_pause_seconds         = var.chaos_ebs_pause
  rto_threshold_seconds     = var.rto_threshold
  
  talos_endpoint       = var.talos_endpoint
  rollback_snapshot_id = var.rollback_snapshot_id
  slack_webhook_url    = var.slack_webhook_url
  alarm_sns_topic_arns = var.alarm_sns_topic_arns
}

# =============================================================================
# Module: Turing Pi Hardware
# =============================================================================

module "turing_pi" {
  source = "./turing-pi"
  
  count = var.enable_turing_pi ? 1 : 0
  
  turingpi_bmc_host = var.turingpi_bmc_host
  turingpi_username = var.turingpi_username
  turingpi_password = var.turingpi_password
  
  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  node_slots       = var.turing_pi_node_slots
  
  power_monitor_enabled    = var.power_monitor_enabled
  power_monitor_url        = var.power_monitor_url
  electricity_cost_per_kwh = var.electricity_cost_per_kwh
  
  aws_free_tier_months_remaining = var.aws_free_tier_months_remaining
}

# =============================================================================
# Module: Stakpak Integration
# =============================================================================

module "stakpak" {
  source = "./stakpak"
  
  count = var.enable_stakpak ? 1 : 0
  
  stakpak_namespace = var.stakpak_namespace
  
  talos_extensions_ref = var.talos_extensions_ref
  talos_version        = var.talos_version
  spin_version         = var.spin_version
  tailscale_version    = var.tailscale_version
  
  build_platforms     = var.build_platforms
  oci_registry        = var.oci_registry
  oci_registry_prefix = var.oci_registry_prefix
  
  deployment_repo_url = var.deployment_repo_url
  deployment_branch   = var.deployment_branch
  cluster_name        = var.cluster_name
  
  slack_webhook_url     = var.slack_webhook_url
  pagerduty_routing_key = var.pagerduty_routing_key
}

# =============================================================================
# Module: Live Stream Infrastructure
# =============================================================================

module "live_stream" {
  source = "./live-stream"
  
  count = var.enable_live_stream ? 1 : 0
  
  aws_region = var.aws_region
  timezone   = var.timezone
  
  mqtt_broker_host = var.mqtt_broker_host
  mqtt_broker_port = var.mqtt_broker_port
  
  obs_websocket_host     = var.obs_websocket_host
  obs_websocket_port     = var.obs_websocket_port
  obs_websocket_password = var.obs_websocket_password
  
  twitch_bot_username = var.twitch_bot_username
  twitch_channels     = var.twitch_channels
  
  fis_stress_template_id      = try(module.chaos_engineering[0].fis_experiment_templates.stress_test, "")
  fis_network_template_id     = try(module.chaos_engineering[0].fis_experiment_templates.network_partition, "")
  fis_termination_template_id = try(module.chaos_engineering[0].fis_experiment_templates.termination, "")
  
  slack_webhook_url = var.slack_webhook_url
  
  cost_warning_threshold = var.cost_warning_threshold
  cost_danger_threshold  = var.cost_danger_threshold
  cost_drama_threshold   = var.cost_drama_threshold
}

# =============================================================================
# Outputs
# =============================================================================

output "chaos_engineering" {
  description = "Chaos engineering module outputs"
  value       = var.enable_chaos_engineering ? module.chaos_engineering[0] : null
}

output "turing_pi" {
  description = "Turing Pi module outputs"
  value       = var.enable_turing_pi ? module.turing_pi[0] : null
}

output "stakpak" {
  description = "Stakpak integration outputs"
  value       = var.enable_stakpak ? module.stakpak[0] : null
}

output "live_stream" {
  description = "Live stream infrastructure outputs"
  value       = var.enable_live_stream ? module.live_stream[0] : null
}

output "episode_summary" {
  description = "Summary of the current episode configuration"
  value = {
    episode_name = var.episode_name
    scenario     = var.scenario
    environment  = var.environment
    modules_enabled = {
      chaos_engineering = var.enable_chaos_engineering
      turing_pi         = var.enable_turing_pi
      stakpak           = var.enable_stakpak
      live_stream       = var.enable_live_stream
    }
  }
}
