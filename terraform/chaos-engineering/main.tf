# =============================================================================
# Sunkworks Chaos Engineering Test Suite
# =============================================================================
# "Productive Failure" methodology - tests that EXPECT failure and validate recovery
# Inspired by CozySummit demo success against Sunkworks expectations
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "sunkworks-chaos"
      Environment = var.environment
      ManagedBy   = "terraform"
      Episode     = var.episode_name
    }
  }
}

# =============================================================================
# AWS Fault Injection Simulator (FIS) - Target t4g ARM64 instances
# =============================================================================

# IAM Role for FIS experiments
resource "aws_iam_role" "fis_role" {
  name = "sunkworks-fis-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "fis.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "fis_policy" {
  name = "sunkworks-fis-policy"
  role = aws_iam_role.fis_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:RebootInstances",
          "ec2:TerminateInstances",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "sunkworks-chaos"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkAcl",
          "ec2:CreateNetworkAclEntry",
          "ec2:DeleteNetworkAcl",
          "ec2:DeleteNetworkAclEntry",
          "ec2:ReplaceNetworkAclAssociation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ebs:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:DeleteLogDelivery"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# FIS Experiment: Instance Stress Test (t4g.micro CPU/memory pressure)
# =============================================================================

resource "aws_fis_experiment_template" "t4g_stress_test" {
  description = "Sunkworks: Stress test t4g.micro instances - the free tier limit"
  role_arn    = aws_iam_role.fis_role.arn

  stop_condition {
    source = "none"
  }

  action {
    name        = "stress-cpu"
    action_id   = "aws:ssm:send-command"
    description = "Run CPU stress on t4g instances"
    
    parameter {
      key   = "documentArn"
      value = "arn:aws:ssm:${var.aws_region}::document/AWSFIS-Run-CPU-Stress"
    }
    
    parameter {
      key   = "documentParameters"
      value = jsonencode({
        DurationSeconds = tostring(var.stress_duration_seconds)
        CPU             = tostring(var.stress_cpu_percent)
      })
    }
    
    parameter {
      key   = "duration"
      value = "PT${ceil(var.stress_duration_seconds / 60) + 2}M"
    }
    
    target {
      key   = "Instances"
      value = "t4g-targets"
    }
  }

  target {
    name           = "t4g-targets"
    resource_type  = "aws:ec2:instance"
    selection_mode = "ALL"

    resource_tag {
      key   = "Architecture"
      value = "arm64"
    }

    resource_tag {
      key   = "Project"
      value = "sunkworks-chaos"
    }
  }

  tags = {
    Name     = "sunkworks-t4g-stress"
    TestType = "stress"
  }
}

# =============================================================================
# FIS Experiment: Network Partition (Tailscale subnet router failure simulation)
# =============================================================================

resource "aws_fis_experiment_template" "network_partition" {
  description = "Sunkworks: Simulate Tailscale subnet router failure between AWS and home lab"
  role_arn    = aws_iam_role.fis_role.arn

  stop_condition {
    source = "none"
  }

  action {
    name        = "block-tailscale-traffic"
    action_id   = "aws:network:disrupt-connectivity"
    description = "Block traffic to Tailscale CIDR ranges"
    
    parameter {
      key   = "duration"
      value = "PT${var.network_partition_minutes}M"
    }
    
    parameter {
      key   = "scope"
      value = "all"
    }
    
    target {
      key   = "Subnets"
      value = "cozystack-subnets"
    }
  }

  target {
    name           = "cozystack-subnets"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Project"
      value = "sunkworks-chaos"
    }
  }

  tags = {
    Name     = "sunkworks-network-partition"
    TestType = "network-partition"
    Scenario = "tailscale-failure"
  }
}

# =============================================================================
# FIS Experiment: EBS Volume Failure During etcd Writes
# =============================================================================

resource "aws_fis_experiment_template" "ebs_etcd_failure" {
  description = "Sunkworks: The 'ship going down' scenario - EBS failure during Talos etcd writes"
  role_arn    = aws_iam_role.fis_role.arn

  stop_condition {
    source = "none"
  }

  action {
    name        = "pause-ebs-io"
    action_id   = "aws:ebs:pause-volume-io"
    description = "Pause EBS I/O to simulate disk failure during etcd writes"
    
    parameter {
      key   = "duration"
      value = "PT${var.ebs_pause_seconds}S"
    }
    
    target {
      key   = "Volumes"
      value = "etcd-volumes"
    }
  }

  target {
    name           = "etcd-volumes"
    resource_type  = "aws:ec2:ebs-volume"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "Role"
      value = "etcd"
    }

    resource_tag {
      key   = "Project"
      value = "sunkworks-chaos"
    }
  }

  tags = {
    Name     = "sunkworks-ebs-etcd-failure"
    TestType = "storage-failure"
    Scenario = "ship-going-down"
  }
}

# =============================================================================
# FIS Experiment: Instance Termination (Spot-like interruption)
# =============================================================================

resource "aws_fis_experiment_template" "instance_termination" {
  description = "Sunkworks: Sudden instance termination - spot interruption simulation"
  role_arn    = aws_iam_role.fis_role.arn

  stop_condition {
    source = "none"
  }

  action {
    name        = "terminate-random-node"
    action_id   = "aws:ec2:terminate-instances"
    description = "Terminate a random CozyStack node"
    
    target {
      key   = "Instances"
      value = "cozystack-nodes"
    }
  }

  target {
    name           = "cozystack-nodes"
    resource_type  = "aws:ec2:instance"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "Role"
      value = "cozystack-node"
    }

    resource_tag {
      key   = "Project"
      value = "sunkworks-chaos"
    }
  }

  tags = {
    Name     = "sunkworks-instance-termination"
    TestType = "instance-failure"
  }
}

# =============================================================================
# CloudWatch Alarms for RTO Validation (< 10 minutes target)
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "rto_breach" {
  alarm_name          = "sunkworks-rto-breach-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RecoveryTimeSeconds"
  namespace           = "Sunkworks/ChaosEngineering"
  period              = 60
  statistic           = "Maximum"
  threshold           = var.rto_threshold_seconds
  alarm_description   = "RTO exceeded ${var.rto_threshold_seconds / 60} minutes - Sunkworks failure scenario"

  dimensions = {
    Environment = var.environment
  }

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns

  tags = {
    Name = "sunkworks-rto-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "bootstrap_failure" {
  alarm_name          = "sunkworks-bootstrap-failure-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "BootstrapSuccess"
  namespace           = "Sunkworks/ChaosEngineering"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "CozyStack bootstrap failed - common Sunkworks outcome"

  dimensions = {
    Environment = var.environment
  }

  alarm_actions = var.alarm_sns_topic_arns

  tags = {
    Name = "sunkworks-bootstrap-alarm"
  }
}

# =============================================================================
# Lambda for Automated Rollback Procedures
# =============================================================================

resource "aws_lambda_function" "rollback_handler" {
  function_name = "sunkworks-rollback-handler-${var.environment}"
  role          = aws_iam_role.lambda_rollback_role.arn
  handler       = "rollback.handler"
  runtime       = "python3.11"
  timeout       = 300
  memory_size   = 256
  architectures = ["arm64"]

  filename         = data.archive_file.rollback_lambda.output_path
  source_code_hash = data.archive_file.rollback_lambda.output_base64sha256

  environment {
    variables = {
      ENVIRONMENT          = var.environment
      TALOS_ENDPOINT       = var.talos_endpoint
      ROLLBACK_SNAPSHOT_ID = var.rollback_snapshot_id
      SLACK_WEBHOOK_URL    = var.slack_webhook_url
    }
  }

  tags = {
    Name = "sunkworks-rollback"
  }
}

resource "aws_iam_role" "lambda_rollback_role" {
  name = "sunkworks-lambda-rollback-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_rollback_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ec2_policy" {
  name = "ec2-management"
  role = aws_iam_role.lambda_rollback_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:CreateVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "autoscaling:UpdateAutoScalingGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda source code
data "archive_file" "rollback_lambda" {
  type        = "zip"
  output_path = "${path.module}/rollback_lambda.zip"

  source {
    content  = file("${path.module}/lambda/rollback.py")
    filename = "rollback.py"
  }
}

# CloudWatch Events rule to trigger rollback on alarm
resource "aws_cloudwatch_event_rule" "bootstrap_failure_trigger" {
  name        = "sunkworks-bootstrap-failure-trigger"
  description = "Trigger rollback when CozyStack bootstrap fails"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = [aws_cloudwatch_metric_alarm.bootstrap_failure.alarm_name]
      state = {
        value = ["ALARM"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "rollback_lambda_target" {
  rule      = aws_cloudwatch_event_rule.bootstrap_failure_trigger.name
  target_id = "sunkworks-rollback"
  arn       = aws_lambda_function.rollback_handler.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rollback_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.bootstrap_failure_trigger.arn
}

# =============================================================================
# Step Functions State Machine for Chaos Test Orchestration
# =============================================================================

resource "aws_sfn_state_machine" "chaos_orchestrator" {
  name     = "sunkworks-chaos-orchestrator-${var.environment}"
  role_arn = aws_iam_role.sfn_role.arn

  definition = jsonencode({
    Comment = "Sunkworks Chaos Engineering Orchestrator - Expects failure, validates recovery"
    StartAt = "RecordTestStart"
    States = {
      RecordTestStart = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:cloudwatch:putMetricData"
        Parameters = {
          Namespace  = "Sunkworks/ChaosEngineering"
          MetricData = [
            {
              MetricName = "TestStarted"
              Value      = 1
              Unit       = "Count"
              Dimensions = [
                {
                  Name  = "Environment"
                  Value = var.environment
                }
              ]
            }
          ]
        }
        Next = "InjectFault"
      }
      InjectFault = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:fis:startExperiment"
        Parameters = {
          "ExperimentTemplateId.$" = "$.experimentTemplateId"
        }
        ResultPath = "$.experimentResult"
        Next       = "WaitForChaos"
      }
      WaitForChaos = {
        Type    = "Wait"
        Seconds = var.chaos_duration_seconds
        Next    = "CheckRecovery"
      }
      CheckRecovery = {
        Type     = "Task"
        Resource = aws_lambda_function.recovery_checker.arn
        ResultPath = "$.recoveryStatus"
        Next     = "EvaluateRTO"
      }
      EvaluateRTO = {
        Type = "Choice"
        Choices = [
          {
            Variable         = "$.recoveryStatus.recoveryTimeSeconds"
            NumericLessThan  = var.rto_threshold_seconds
            Next             = "TestPassed"
          }
        ]
        Default = "TestFailed"
      }
      TestPassed = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:cloudwatch:putMetricData"
        Parameters = {
          Namespace  = "Sunkworks/ChaosEngineering"
          MetricData = [
            {
              MetricName = "TestPassed"
              Value      = 1
              Unit       = "Count"
            }
          ]
        }
        Next = "RecordRecoveryTime"
      }
      TestFailed = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:cloudwatch:putMetricData"
        Parameters = {
          Namespace  = "Sunkworks/ChaosEngineering"
          MetricData = [
            {
              MetricName = "TestFailed"
              Value      = 1
              Unit       = "Count"
            }
          ]
        }
        Next = "TriggerRollback"
      }
      TriggerRollback = {
        Type     = "Task"
        Resource = aws_lambda_function.rollback_handler.arn
        Next     = "RecordRecoveryTime"
      }
      RecordRecoveryTime = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:cloudwatch:putMetricData"
        Parameters = {
          Namespace  = "Sunkworks/ChaosEngineering"
          MetricData = [
            {
              MetricName = "RecoveryTimeSeconds"
              "Value.$"  = "$.recoveryStatus.recoveryTimeSeconds"
              Unit       = "Seconds"
            }
          ]
        }
        End = true
      }
    }
  })

  tags = {
    Name = "sunkworks-chaos-orchestrator"
  }
}

resource "aws_iam_role" "sfn_role" {
  name = "sunkworks-sfn-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "sfn_policy" {
  name = "sfn-chaos-policy"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "fis:StartExperiment",
          "fis:GetExperiment",
          "lambda:InvokeFunction",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Recovery checker Lambda
resource "aws_lambda_function" "recovery_checker" {
  function_name = "sunkworks-recovery-checker-${var.environment}"
  role          = aws_iam_role.lambda_rollback_role.arn
  handler       = "recovery_checker.handler"
  runtime       = "python3.11"
  timeout       = 60
  architectures = ["arm64"]

  filename         = data.archive_file.recovery_checker_lambda.output_path
  source_code_hash = data.archive_file.recovery_checker_lambda.output_base64sha256

  environment {
    variables = {
      TALOS_ENDPOINT = var.talos_endpoint
    }
  }
}

data "archive_file" "recovery_checker_lambda" {
  type        = "zip"
  output_path = "${path.module}/recovery_checker_lambda.zip"

  source {
    content  = file("${path.module}/lambda/recovery_checker.py")
    filename = "recovery_checker.py"
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "fis_experiment_templates" {
  description = "FIS experiment template ARNs for chaos testing"
  value = {
    stress_test       = aws_fis_experiment_template.t4g_stress_test.id
    network_partition = aws_fis_experiment_template.network_partition.id
    ebs_failure       = aws_fis_experiment_template.ebs_etcd_failure.id
    termination       = aws_fis_experiment_template.instance_termination.id
  }
}

output "chaos_orchestrator_arn" {
  description = "Step Functions state machine ARN for chaos orchestration"
  value       = aws_sfn_state_machine.chaos_orchestrator.arn
}

output "rollback_lambda_arn" {
  description = "Rollback handler Lambda ARN"
  value       = aws_lambda_function.rollback_handler.arn
}
