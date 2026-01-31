# =============================================================================
# Live Stream Infrastructure Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for cost monitoring"
  type        = string
  default     = "us-east-1"
}

variable "timezone" {
  description = "Timezone for stream timestamps"
  type        = string
  default     = "America/New_York"
}

# =============================================================================
# MQTT Configuration
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

# =============================================================================
# OBS Configuration
# =============================================================================

variable "obs_websocket_host" {
  description = "OBS WebSocket server host"
  type        = string
  default     = "localhost"
}

variable "obs_websocket_port" {
  description = "OBS WebSocket server port"
  type        = number
  default     = 4455
}

variable "obs_websocket_password" {
  description = "OBS WebSocket password"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Twitch Configuration
# =============================================================================

variable "twitch_bot_username" {
  description = "Twitch bot username"
  type        = string
  default     = "SunkworksBot"
}

variable "twitch_channels" {
  description = "Twitch channels to join"
  type        = list(string)
  default     = ["sunkworks"]
}

variable "twitch_client_id" {
  description = "Twitch application client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "twitch_client_secret" {
  description = "Twitch application client secret"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Chaos Integration
# =============================================================================

variable "fis_stress_template_id" {
  description = "FIS experiment template ID for stress tests"
  type        = string
  default     = ""
}

variable "fis_network_template_id" {
  description = "FIS experiment template ID for network partition"
  type        = string
  default     = ""
}

variable "fis_termination_template_id" {
  description = "FIS experiment template ID for instance termination"
  type        = string
  default     = ""
}

# =============================================================================
# Notification Configuration
# =============================================================================

variable "slack_webhook_url" {
  description = "Slack webhook for stream notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "discord_webhook_url" {
  description = "Discord webhook for stream notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Cost Thresholds (for drama alerts)
# =============================================================================

variable "cost_warning_threshold" {
  description = "Monthly cost threshold for warning (yellow)"
  type        = number
  default     = 5.0
}

variable "cost_danger_threshold" {
  description = "Monthly cost threshold for danger (red)"
  type        = number
  default     = 10.0
}

variable "cost_drama_threshold" {
  description = "Monthly cost threshold for maximum drama"
  type        = number
  default     = 15.0
}
