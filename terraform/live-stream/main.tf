# =============================================================================
# Sunkworks Live Stream Infrastructure
# =============================================================================
# OBS automation, real-time cost overlays, chaos integration for episodes
# "Technical difficulty" automation and chat-integrated chaos commands
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# =============================================================================
# Node-RED Flow: OBS Scene Automation
# =============================================================================

resource "local_file" "nodered_obs_flow" {
  filename = "${path.module}/generated/nodered/obs-automation-flow.json"
  
  content = jsonencode([
    # MQTT Input - Health Check Status
    {
      id       = "mqtt-health-in"
      type     = "mqtt in"
      name     = "Health Check Status"
      topic    = "sunkworks/health/status"
      qos      = "1"
      broker   = "mqtt-broker"
      wires    = [["health-switch"]]
    },
    
    # MQTT Input - Chaos Commands from Chat
    {
      id       = "mqtt-chaos-in"
      type     = "mqtt in"
      name     = "Chat Chaos Commands"
      topic    = "sunkworks/chat/commands"
      qos      = "1"
      broker   = "mqtt-broker"
      wires    = [["chaos-command-handler"]]
    },
    
    # Health Status Switch
    {
      id    = "health-switch"
      type  = "switch"
      name  = "Health Status Router"
      property = "payload.status"
      rules = [
        { t = "eq", v = "healthy", vt = "str" },
        { t = "eq", v = "degraded", vt = "str" },
        { t = "eq", v = "failed", vt = "str" }
      ]
      wires = [
        ["scene-normal"],
        ["scene-warning"],
        ["scene-technical-difficulty"]
      ]
    },
    
    # Scene: Normal Operation
    {
      id      = "scene-normal"
      type    = "function"
      name    = "Set Normal Scene"
      func    = <<-EOF
        msg.payload = {
            "request-type": "SetCurrentScene",
            "scene-name": "Sunkworks - Live"
        };
        return msg;
      EOF
      wires   = [["obs-websocket-out"]]
    },
    
    # Scene: Warning/Degraded
    {
      id      = "scene-warning"
      type    = "function"
      name    = "Set Warning Scene"
      func    = <<-EOF
        msg.payload = {
            "request-type": "SetCurrentScene",
            "scene-name": "Sunkworks - Warning"
        };
        // Also update overlay text
        node.send([msg, {
            payload: {
                "request-type": "SetTextGDIPlusProperties",
                "source": "status-text",
                "text": "⚠️ EXPERIENCING ISSUES - STAND BY"
            }
        }]);
        return null;
      EOF
      wires   = [["obs-websocket-out"], ["obs-websocket-out"]]
    },
    
    # Scene: Technical Difficulty
    {
      id      = "scene-technical-difficulty"
      type    = "function"
      name    = "Set Technical Difficulty"
      func    = <<-EOF
        msg.payload = {
            "request-type": "SetCurrentScene",
            "scene-name": "Sunkworks - Technical Difficulty"
        };
        // Log the failure timestamp
        global.set("failure_start", Date.now());
        return msg;
      EOF
      wires   = [["obs-websocket-out", "failure-logger"]]
    },
    
    # Chaos Command Handler
    {
      id      = "chaos-command-handler"
      type    = "function"
      name    = "Handle Chaos Commands"
      func    = <<-EOF
        const cmd = msg.payload.command;
        const user = msg.payload.user;
        const args = msg.payload.args || [];
        
        // Command whitelist and permissions
        const commands = {
            "!sinktheship": { 
                permission: "moderator",
                action: "full-chaos"
            },
            "!networkblip": {
                permission: "subscriber",
                action: "network-partition"
            },
            "!stresstest": {
                permission: "subscriber",
                action: "cpu-stress"
            },
            "!status": {
                permission: "everyone",
                action: "status-check"
            },
            "!rollback": {
                permission: "moderator",
                action: "trigger-rollback"
            }
        };
        
        const cmdConfig = commands[cmd.toLowerCase()];
        if (!cmdConfig) {
            return null; // Unknown command
        }
        
        // Check permissions
        if (cmdConfig.permission === "moderator" && !msg.payload.isModerator) {
            msg.payload = { reply: "Nice try! Only moderators can trigger that chaos." };
            return [null, msg];
        }
        
        msg.chaos_action = cmdConfig.action;
        msg.triggered_by = user;
        return [msg, null];
      EOF
      wires   = [["chaos-executor"], ["chat-reply"]]
    },
    
    # Chaos Executor
    {
      id      = "chaos-executor"
      type    = "function"
      name    = "Execute Chaos Command"
      func    = <<-EOF
        const action = msg.chaos_action;
        const user = msg.triggered_by;
        
        // Map to FIS experiment templates
        const experiments = {
            "full-chaos": {
                template_id: global.get("fis_termination_template"),
                announcement: "🚢 " + user + " triggered !sinktheship - BRACE FOR IMPACT!"
            },
            "network-partition": {
                template_id: global.get("fis_network_template"),
                announcement: "🌐 " + user + " triggered network chaos!"
            },
            "cpu-stress": {
                template_id: global.get("fis_stress_template"),
                announcement: "🔥 " + user + " is stress testing the cluster!"
            },
            "status-check": {
                check_only: true
            },
            "trigger-rollback": {
                rollback: true,
                announcement: "🔄 " + user + " triggered emergency rollback!"
            }
        };
        
        const exp = experiments[action];
        if (exp.check_only) {
            msg.payload = { action: "check-status" };
            return [null, msg, null];
        }
        
        if (exp.rollback) {
            msg.payload = { action: "trigger-rollback" };
            return [null, null, msg];
        }
        
        // Start FIS experiment
        msg.payload = {
            experiment_template_id: exp.template_id
        };
        msg.announcement = exp.announcement;
        
        return [msg, null, null];
      EOF
      wires   = [["aws-fis-start", "announcer"], ["status-checker"], ["rollback-trigger"]]
    },
    
    # OBS WebSocket Output
    {
      id     = "obs-websocket-out"
      type   = "websocket out"
      name   = "OBS WebSocket"
      server = "obs-ws-server"
      client = ""
    },
    
    # MQTT Broker Configuration
    {
      id         = "mqtt-broker"
      type       = "mqtt-broker"
      name       = "Home Lab MQTT"
      broker     = var.mqtt_broker_host
      port       = var.mqtt_broker_port
      clientid   = "nodered-sunkworks"
      autoConnect = true
      usetls     = false
    }
  ])
}

# =============================================================================
# Node-RED Flow: Real-Time Cost Overlay
# =============================================================================

resource "local_file" "nodered_cost_flow" {
  filename = "${path.module}/generated/nodered/cost-overlay-flow.json"
  
  content = jsonencode([
    # AWS Cost Polling (every 30 seconds)
    {
      id      = "cost-poll-interval"
      type    = "inject"
      name    = "Poll AWS Costs"
      repeat  = "30"
      payload = ""
      wires   = [["aws-cost-fetch"]]
    },
    
    # Fetch Current AWS Costs
    {
      id      = "aws-cost-fetch"
      type    = "http request"
      name    = "Get AWS Cost Data"
      method  = "GET"
      url     = "http://localhost:8080/api/costs/current"  # Local cost aggregator
      ret     = "obj"
      wires   = [["cost-formatter"]]
    },
    
    # Format Cost for OBS
    {
      id      = "cost-formatter"
      type    = "function"
      name    = "Format Cost Display"
      func    = <<-EOF
        const costs = msg.payload;
        
        // Current month costs
        const monthTotal = costs.month_to_date || 0;
        const todayTotal = costs.today || 0;
        const hourlyRate = costs.current_hourly_rate || 0;
        
        // Stream session costs
        const sessionStart = global.get("stream_session_start") || Date.now();
        const sessionHours = (Date.now() - sessionStart) / 3600000;
        const sessionCost = hourlyRate * sessionHours;
        
        // Format the display text
        let costColor = "#00FF00"; // Green
        if (monthTotal > 5) costColor = "#FFFF00"; // Yellow
        if (monthTotal > 10) costColor = "#FF6600"; // Orange
        if (monthTotal > 15) costColor = "#FF0000"; // Red - THE DRAMA!
        
        // The "$0.04/month → $15/month" drama meter
        const freeT4gHours = costs.free_tier_hours_remaining || 0;
        const dramaLevel = freeT4gHours < 100 ? "🔥" : (freeT4gHours < 500 ? "⚠️" : "✅");
        
        msg.payload = {
            "request-type": "SetTextGDIPlusProperties",
            "source": "cost-overlay",
            "text": [
                "💰 AWS Burn Rate",
                "────────────────",
                "This Stream: $" + sessionCost.toFixed(4),
                "Today: $" + todayTotal.toFixed(2),
                "Month: $" + monthTotal.toFixed(2),
                "────────────────",
                dramaLevel + " Free Tier: " + freeT4gHours.toFixed(0) + "h left"
            ].join("\\n"),
            "color": costColor
        };
        
        // Store for dashboard
        global.set("current_costs", {
            session: sessionCost,
            today: todayTotal,
            month: monthTotal,
            color: costColor,
            drama_level: dramaLevel
        });
        
        return msg;
      EOF
      wires   = [["obs-websocket-out", "cost-dashboard"]]
    },
    
    # Dashboard Output
    {
      id     = "cost-dashboard"
      type   = "ui_gauge"
      name   = "Cost Gauge"
      group  = "sunkworks-dashboard"
      order  = 1
      width  = 4
      height = 3
      gtype  = "gage"
      title  = "Monthly AWS Cost"
      label  = "$"
      format = "{{value | number:2}}"
      min    = 0
      max    = 20
      colors = ["#00FF00", "#FFFF00", "#FF0000"]
      seg1   = 5
      seg2   = 10
    },
    
    # Stream Start Handler
    {
      id      = "stream-start"
      type    = "mqtt in"
      name    = "Stream Started"
      topic   = "sunkworks/stream/start"
      qos     = "1"
      broker  = "mqtt-broker"
      wires   = [["stream-start-handler"]]
    },
    
    {
      id      = "stream-start-handler"
      type    = "function"
      name    = "Initialize Stream Session"
      func    = <<-EOF
        global.set("stream_session_start", Date.now());
        global.set("stream_session_cost_start", global.get("current_costs")?.month || 0);
        
        msg.payload = {
            event: "stream_started",
            timestamp: new Date().toISOString()
        };
        return msg;
      EOF
      wires   = [["session-logger"]]
    }
  ])
}

# =============================================================================
# Cost Aggregator Service (Python)
# =============================================================================

resource "local_file" "cost_aggregator" {
  filename = "${path.module}/generated/cost-aggregator/main.py"
  
  content = <<-EOF
    """
    Sunkworks Cost Aggregator
    Real-time AWS cost tracking for stream overlay
    """
    
    import json
    import os
    from datetime import datetime, timezone
    from flask import Flask, jsonify
    import boto3
    from functools import lru_cache
    import threading
    import time
    
    app = Flask(__name__)
    
    # AWS Cost Explorer client
    ce = boto3.client('ce', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
    ec2 = boto3.client('ec2', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
    
    # Cache for cost data
    cost_cache = {
        'month_to_date': 0,
        'today': 0,
        'current_hourly_rate': 0,
        'free_tier_hours_remaining': 750,
        'last_updated': None
    }
    
    
    def update_costs():
        """Background task to update cost data from AWS."""
        while True:
            try:
                today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
                first_of_month = datetime.now(timezone.utc).strftime('%Y-%m-01')
                
                # Get month-to-date costs
                response = ce.get_cost_and_usage(
                    TimePeriod={
                        'Start': first_of_month,
                        'End': today
                    },
                    Granularity='MONTHLY',
                    Metrics=['UnblendedCost'],
                    Filter={
                        'Tags': {
                            'Key': 'Project',
                            'Values': ['sunkworks-chaos', 'cozystack']
                        }
                    }
                )
                
                if response['ResultsByTime']:
                    cost_cache['month_to_date'] = float(
                        response['ResultsByTime'][0]['Total']['UnblendedCost']['Amount']
                    )
                
                # Get today's costs
                yesterday = (datetime.now(timezone.utc) - timedelta(days=1)).strftime('%Y-%m-%d')
                response = ce.get_cost_and_usage(
                    TimePeriod={
                        'Start': yesterday,
                        'End': today
                    },
                    Granularity='DAILY',
                    Metrics=['UnblendedCost']
                )
                
                if response['ResultsByTime']:
                    cost_cache['today'] = float(
                        response['ResultsByTime'][-1]['Total']['UnblendedCost']['Amount']
                    )
                
                # Calculate current hourly rate based on running instances
                instances = ec2.describe_instances(
                    Filters=[
                        {'Name': 'instance-state-name', 'Values': ['running']},
                        {'Name': 'tag:Project', 'Values': ['sunkworks-chaos', 'cozystack']}
                    ]
                )
                
                hourly_rate = 0
                for reservation in instances['Reservations']:
                    for instance in reservation['Instances']:
                        # t4g.micro: $0.0084/hour (but free tier eligible!)
                        instance_type = instance['InstanceType']
                        if instance_type == 't4g.micro':
                            hourly_rate += 0.0084
                        elif instance_type == 't4g.small':
                            hourly_rate += 0.0168
                        elif instance_type == 't4g.medium':
                            hourly_rate += 0.0336
                        else:
                            hourly_rate += 0.05  # Default estimate
                
                cost_cache['current_hourly_rate'] = hourly_rate
                
                # Estimate free tier remaining (750 hours/month for t4g.micro)
                days_in_month = 30
                current_day = datetime.now().day
                used_hours = current_day * 24  # Simplified estimate
                cost_cache['free_tier_hours_remaining'] = max(0, 750 - used_hours)
                
                cost_cache['last_updated'] = datetime.now(timezone.utc).isoformat()
                
            except Exception as e:
                print(f"Error updating costs: {e}")
            
            # Update every 30 seconds
            time.sleep(30)
    
    
    @app.route('/api/costs/current')
    def get_current_costs():
        """Return current cost data for OBS overlay."""
        return jsonify(cost_cache)
    
    
    @app.route('/api/costs/drama')
    def get_drama_level():
        """Return the drama level for the stream."""
        month = cost_cache['month_to_date']
        
        if month < 0.05:
            return jsonify({
                'level': 'chill',
                'message': '$0.04/month mode - living the dream',
                'emoji': '😎'
            })
        elif month < 1:
            return jsonify({
                'level': 'normal',
                'message': 'Costs are climbing, stay vigilant',
                'emoji': '👀'
            })
        elif month < 5:
            return jsonify({
                'level': 'concerning',
                'message': 'Entering Sunkworks territory',
                'emoji': '⚠️'
            })
        elif month < 15:
            return jsonify({
                'level': 'drama',
                'message': 'THE $15/MONTH NIGHTMARE IS REAL',
                'emoji': '🔥'
            })
        else:
            return jsonify({
                'level': 'catastrophic',
                'message': 'BEYOND SUNKWORKS PREDICTION',
                'emoji': '💀'
            })
    
    
    if __name__ == '__main__':
        # Start background cost updater
        update_thread = threading.Thread(target=update_costs, daemon=True)
        update_thread.start()
        
        app.run(host='0.0.0.0', port=8080)
  EOF
}

# =============================================================================
# Twitch Chat Bot Configuration
# =============================================================================

resource "local_file" "twitch_bot_config" {
  filename = "${path.module}/generated/chatbot/config.yaml"
  
  content = yamlencode({
    bot = {
      username = var.twitch_bot_username
      channels = var.twitch_channels
    }
    
    mqtt = {
      broker = var.mqtt_broker_host
      port   = var.mqtt_broker_port
      topics = {
        commands = "sunkworks/chat/commands"
        replies  = "sunkworks/chat/replies"
        events   = "sunkworks/chat/events"
      }
    }
    
    commands = {
      # Chaos commands
      "!sinktheship" = {
        description   = "Trigger maximum chaos - terminate a random node"
        permission    = "moderator"
        cooldown      = 300  # 5 minutes
        confirmation  = "🚢 BRACE FOR IMPACT! Triggering full chaos protocol..."
      }
      
      "!networkblip" = {
        description   = "Simulate network partition"
        permission    = "subscriber"
        cooldown      = 120
        confirmation  = "🌐 Network chaos incoming!"
      }
      
      "!stresstest" = {
        description   = "Run CPU stress test on cluster"
        permission    = "subscriber"
        cooldown      = 180
        confirmation  = "🔥 Stress testing initiated!"
      }
      
      "!status" = {
        description   = "Check cluster health status"
        permission    = "everyone"
        cooldown      = 10
        # Response handled by status-checker
      }
      
      "!rollback" = {
        description   = "Trigger emergency rollback"
        permission    = "moderator"
        cooldown      = 600  # 10 minutes
        confirmation  = "🔄 Emergency rollback initiated!"
      }
      
      "!costs" = {
        description   = "Show current AWS costs"
        permission    = "everyone"
        cooldown      = 30
        # Response shows current burn rate
      }
      
      "!drama" = {
        description   = "Get the current drama level"
        permission    = "everyone"
        cooldown      = 60
        # Response shows drama meter
      }
    }
    
    rewards = {
      # Channel point redemptions
      "Trigger Minor Chaos" = {
        action = "networkblip"
        cost   = 1000
      }
      
      "Stress the Cluster" = {
        action = "stresstest"
        cost   = 2500
      }
      
      "SINK THE SHIP" = {
        action = "sinktheship"
        cost   = 10000
        moderator_only = true
      }
    }
    
    # Auto-responses based on events
    events = {
      on_health_degraded = {
        message = "⚠️ Cluster health is degrading! Will it survive? Stay tuned..."
      }
      
      on_health_failed = {
        message = "🚨 TECHNICAL DIFFICULTY - The cluster is down! Recovery incoming..."
      }
      
      on_recovery_started = {
        message = "🔄 Recovery process started. RTO target: 10 minutes. Clock is ticking!"
      }
      
      on_recovery_complete = {
        message = "✅ We're back! Recovery time: {recovery_time}s"
      }
      
      on_cost_threshold = {
        thresholds = [1, 5, 10, 15]
        message    = "💰 AWS costs just hit ${threshold}! The $0.04/month dream is slipping away..."
      }
    }
  })
}

# =============================================================================
# Docker Compose for Local Stream Stack
# =============================================================================

resource "local_file" "docker_compose" {
  filename = "${path.module}/generated/docker-compose.yaml"
  
  content = yamlencode({
    version = "3.8"
    
    services = {
      # MQTT Broker
      mqtt = {
        image   = "eclipse-mosquitto:2"
        ports   = ["1883:1883", "9001:9001"]
        volumes = [
          "./mosquitto/config:/mosquitto/config",
          "./mosquitto/data:/mosquitto/data"
        ]
        restart = "unless-stopped"
      }
      
      # Node-RED
      nodered = {
        image   = "nodered/node-red:latest"
        ports   = ["1880:1880"]
        volumes = [
          "./nodered:/data"
        ]
        environment = {
          TZ = var.timezone
        }
        depends_on = ["mqtt"]
        restart    = "unless-stopped"
      }
      
      # Cost Aggregator
      cost-aggregator = {
        build = "./cost-aggregator"
        ports = ["8080:8080"]
        environment = {
          AWS_REGION            = var.aws_region
          AWS_ACCESS_KEY_ID     = "$${AWS_ACCESS_KEY_ID}"
          AWS_SECRET_ACCESS_KEY = "$${AWS_SECRET_ACCESS_KEY}"
        }
        restart = "unless-stopped"
      }
      
      # Twitch Chat Bot
      chatbot = {
        build = "./chatbot"
        environment = {
          TWITCH_CLIENT_ID     = "$${TWITCH_CLIENT_ID}"
          TWITCH_CLIENT_SECRET = "$${TWITCH_CLIENT_SECRET}"
          TWITCH_ACCESS_TOKEN  = "$${TWITCH_ACCESS_TOKEN}"
          MQTT_BROKER          = "mqtt"
          MQTT_PORT            = "1883"
        }
        depends_on = ["mqtt"]
        restart    = "unless-stopped"
      }
      
      # Grafana Dashboard
      grafana = {
        image = "grafana/grafana:latest"
        ports = ["3000:3000"]
        volumes = [
          "./grafana/provisioning:/etc/grafana/provisioning",
          "grafana-data:/var/lib/grafana"
        ]
        environment = {
          GF_SECURITY_ADMIN_PASSWORD = "$${GRAFANA_PASSWORD}"
          GF_AUTH_ANONYMOUS_ENABLED  = "true"
        }
        restart = "unless-stopped"
      }
      
      # Prometheus for metrics
      prometheus = {
        image = "prom/prometheus:latest"
        ports = ["9090:9090"]
        volumes = [
          "./prometheus:/etc/prometheus"
        ]
        restart = "unless-stopped"
      }
    }
    
    volumes = {
      grafana-data = {}
    }
    
    networks = {
      default = {
        name = "sunkworks-stream"
      }
    }
  })
}

# =============================================================================
# OBS Scene Collection Template
# =============================================================================

resource "local_file" "obs_scenes" {
  filename = "${path.module}/generated/obs/scene-collection.json"
  
  content = jsonencode({
    name = "Sunkworks Episodes"
    
    scenes = [
      {
        name = "Sunkworks - Live"
        sources = [
          {
            name     = "main-capture"
            type     = "screen_capture"
            settings = {
              method = "window_capture"
            }
          },
          {
            name     = "webcam"
            type     = "v4l2_input"
            settings = {
              device = "/dev/video0"
            }
          },
          {
            name     = "cost-overlay"
            type     = "text_gdiplus"
            settings = {
              font = {
                face  = "JetBrains Mono"
                size  = 24
                flags = 0
              }
              outline       = true
              outline_color = 0x000000
              color         = 0x00FF00
            }
          },
          {
            name     = "status-indicator"
            type     = "color_source"
            settings = {
              color  = 0x00FF00
              width  = 20
              height = 20
            }
          }
        ]
      },
      
      {
        name = "Sunkworks - Warning"
        sources = [
          {
            name     = "main-capture"
            type     = "screen_capture"
          },
          {
            name     = "warning-banner"
            type     = "image_source"
            settings = {
              file = "./assets/warning-banner.png"
            }
          },
          {
            name     = "status-text"
            type     = "text_gdiplus"
            settings = {
              text  = "⚠️ EXPERIENCING ISSUES"
              font = {
                face = "JetBrains Mono"
                size = 48
              }
              color = 0xFFFF00
            }
          }
        ]
      },
      
      {
        name = "Sunkworks - Technical Difficulty"
        sources = [
          {
            name     = "technical-difficulty-screen"
            type     = "image_source"
            settings = {
              file = "./assets/technical-difficulty.png"
            }
          },
          {
            name     = "recovery-timer"
            type     = "text_gdiplus"
            settings = {
              text  = "Recovery in progress..."
              font = {
                face = "JetBrains Mono"
                size = 36
              }
              color = 0xFF6600
            }
          },
          {
            name     = "elevator-music"
            type     = "ffmpeg_source"
            settings = {
              local_file      = "./assets/elevator-music.mp3"
              looping         = true
              restart_on_activate = true
            }
          }
        ]
      },
      
      {
        name = "Sunkworks - Chaos Mode"
        sources = [
          {
            name     = "main-capture"
            type     = "screen_capture"
          },
          {
            name     = "chaos-overlay"
            type     = "image_source"
            settings = {
              file = "./assets/chaos-border.png"
            }
          },
          {
            name     = "chaos-alert"
            type     = "browser_source"
            settings = {
              url    = "http://localhost:1880/ui/chaos-alert"
              width  = 400
              height = 100
            }
          },
          {
            name     = "sirens"
            type     = "ffmpeg_source"
            settings = {
              local_file = "./assets/alarm.mp3"
              looping    = false
            }
          }
        ]
      }
    ]
  })
}

# =============================================================================
# Outputs
# =============================================================================

output "nodered_flows" {
  description = "Generated Node-RED flow files"
  value = {
    obs_automation = local_file.nodered_obs_flow.filename
    cost_overlay   = local_file.nodered_cost_flow.filename
  }
}

output "stream_stack_compose" {
  description = "Docker Compose file for stream infrastructure"
  value       = local_file.docker_compose.filename
}

output "obs_scenes" {
  description = "OBS scene collection template"
  value       = local_file.obs_scenes.filename
}

output "chatbot_config" {
  description = "Twitch chat bot configuration"
  value       = local_file.twitch_bot_config.filename
}
