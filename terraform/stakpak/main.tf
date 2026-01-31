# =============================================================================
# Stakpak Integration - DevOps Automation
# =============================================================================
# Stakpak configuration for generating Talos extensions from source
# GitOps bridge: Stakpak → Flux → CozyStack deployment pipeline
# Includes Sunkworks contingency for rollback when configs fail validation
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "~> 1.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# =============================================================================
# Stakpak Configuration for Talos Extensions
# =============================================================================

# Generate Stakpak configuration for spin extension
resource "local_file" "stakpak_spin_config" {
  filename = "${path.module}/generated/stakpak-spin.yaml"
  
  content = yamlencode({
    apiVersion = "stakpak.dev/v1alpha1"
    kind       = "ExtensionBuild"
    
    metadata = {
      name      = "talos-spin-extension"
      namespace = var.stakpak_namespace
    }
    
    spec = {
      # Source repository for spin containerd-shim
      source = {
        type = "git"
        git = {
          url    = "https://github.com/siderolabs/extensions"
          ref    = var.talos_extensions_ref
          path   = "container-runtime/spin"
        }
      }
      
      # Build configuration
      build = {
        dockerfile = "Dockerfile"
        context    = "."
        platform   = var.build_platforms
        args = {
          SPIN_VERSION = var.spin_version
        }
      }
      
      # Output OCI image
      output = {
        registry = var.oci_registry
        repository = "${var.oci_registry_prefix}/spin"
        tag = var.spin_version
        push = true
      }
      
      # Validation
      validation = {
        enabled = true
        tests = [
          "extension-validate",
          "talos-upgrade-test"
        ]
      }
      
      # Sunkworks contingency
      onFailure = {
        action = "rollback"
        notification = {
          slack = {
            webhook = var.slack_webhook_url
            channel = "#sunkworks-builds"
          }
        }
      }
    }
  })
}

# Generate Stakpak configuration for tailscale extension
resource "local_file" "stakpak_tailscale_config" {
  filename = "${path.module}/generated/stakpak-tailscale.yaml"
  
  content = yamlencode({
    apiVersion = "stakpak.dev/v1alpha1"
    kind       = "ExtensionBuild"
    
    metadata = {
      name      = "talos-tailscale-extension"
      namespace = var.stakpak_namespace
    }
    
    spec = {
      source = {
        type = "git"
        git = {
          url    = "https://github.com/siderolabs/extensions"
          ref    = var.talos_extensions_ref
          path   = "network/tailscale"
        }
      }
      
      build = {
        dockerfile = "Dockerfile"
        context    = "."
        platform   = var.build_platforms
        args = {
          TAILSCALE_VERSION = var.tailscale_version
        }
      }
      
      output = {
        registry   = var.oci_registry
        repository = "${var.oci_registry_prefix}/tailscale"
        tag        = var.tailscale_version
        push       = true
      }
      
      validation = {
        enabled = true
        tests = [
          "extension-validate",
          "tailscale-connectivity-test"
        ]
      }
      
      onFailure = {
        action = "rollback"
        notification = {
          slack = {
            webhook = var.slack_webhook_url
            channel = "#sunkworks-builds"
          }
        }
      }
    }
  })
}

# =============================================================================
# Stakpak Upstream Watcher - Auto-build on CozyStack Changes
# =============================================================================

resource "local_file" "stakpak_cozystack_watcher" {
  filename = "${path.module}/generated/stakpak-cozystack-watcher.yaml"
  
  content = yamlencode({
    apiVersion = "stakpak.dev/v1alpha1"
    kind       = "SourceWatcher"
    
    metadata = {
      name      = "cozystack-upstream-watcher"
      namespace = var.stakpak_namespace
    }
    
    spec = {
      # Watch upstream CozyStack for changes
      sources = [
        {
          name = "cozystack-main"
          type = "git"
          git = {
            url = "https://github.com/aenix-io/cozystack"
            ref = "main"
            path = "packages/"
          }
          interval = "5m"
        },
        {
          name = "talos-extensions"
          type = "git"
          git = {
            url = "https://github.com/siderolabs/extensions"
            ref = "main"
            path = "/"
          }
          interval = "15m"
        }
      ]
      
      # Trigger builds on change
      triggers = [
        {
          source = "cozystack-main"
          onChange = {
            paths = ["packages/core/*", "packages/extra/*"]
            action = "rebuild"
            targets = ["cozystack-arm64-image"]
          }
        },
        {
          source = "talos-extensions"
          onChange = {
            paths = ["container-runtime/spin/*", "network/tailscale/*"]
            action = "rebuild"
            targets = ["talos-spin-extension", "talos-tailscale-extension"]
          }
        }
      ]
      
      # Debounce to avoid excessive builds
      debounce = "10m"
    }
  })
}

# =============================================================================
# Flux GitOps Bridge Configuration
# =============================================================================

resource "local_file" "flux_gitrepository" {
  filename = "${path.module}/generated/flux/git-repository.yaml"
  
  content = yamlencode({
    apiVersion = "source.toolkit.fluxcd.io/v1"
    kind       = "GitRepository"
    
    metadata = {
      name      = "cozystack-deployment"
      namespace = "flux-system"
    }
    
    spec = {
      interval = "1m"
      url      = var.deployment_repo_url
      ref = {
        branch = var.deployment_branch
      }
      secretRef = {
        name = "github-deploy-key"
      }
    }
  })
}

resource "local_file" "flux_ocirepository" {
  filename = "${path.module}/generated/flux/oci-repository.yaml"
  
  content = yamlencode({
    apiVersion = "source.toolkit.fluxcd.io/v1beta2"
    kind       = "OCIRepository"
    
    metadata = {
      name      = "stakpak-artifacts"
      namespace = "flux-system"
    }
    
    spec = {
      interval = "5m"
      url      = "oci://${var.oci_registry}/${var.oci_registry_prefix}"
      ref = {
        semver = ">=0.0.0"
      }
      provider = "generic"
    }
  })
}

resource "local_file" "flux_kustomization" {
  filename = "${path.module}/generated/flux/kustomization.yaml"
  
  content = yamlencode({
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind       = "Kustomization"
    
    metadata = {
      name      = "cozystack-deployment"
      namespace = "flux-system"
    }
    
    spec = {
      interval    = "5m"
      path        = "./deploy"
      prune       = true
      sourceRef = {
        kind = "GitRepository"
        name = "cozystack-deployment"
      }
      
      # Health checks for deployment validation
      healthChecks = [
        {
          apiVersion = "apps/v1"
          kind       = "Deployment"
          name       = "cozystack-operator"
          namespace  = "cozystack-system"
        }
      ]
      
      # Timeout for deployment
      timeout = "10m"
      
      # Post-build variable substitution
      postBuild = {
        substitute = {
          CLUSTER_NAME   = var.cluster_name
          OCI_REGISTRY   = var.oci_registry
          TALOS_VERSION  = var.talos_version
          SPIN_VERSION   = var.spin_version
        }
        substituteFrom = [
          {
            kind = "Secret"
            name = "cluster-vars"
          }
        ]
      }
    }
  })
}

# =============================================================================
# Rollback Strategy Configuration
# =============================================================================

resource "local_file" "rollback_config" {
  filename = "${path.module}/generated/rollback-config.yaml"
  
  content = yamlencode({
    apiVersion = "stakpak.dev/v1alpha1"
    kind       = "RollbackStrategy"
    
    metadata = {
      name      = "sunkworks-contingency"
      namespace = var.stakpak_namespace
    }
    
    spec = {
      # Validation gate before promoting to production
      validation = {
        # Must pass these checks before deployment
        gates = [
          {
            name = "talos-config-validate"
            type = "command"
            command = ["talosctl", "validate", "-m", "metal"]
            timeout = "5m"
          },
          {
            name = "helm-template-validate"
            type = "command"
            command = ["helm", "template", "--debug"]
            timeout = "2m"
          },
          {
            name = "flux-reconcile-dry-run"  
            type = "flux-check"
            timeout = "5m"
          }
        ]
        
        # Fail fast on validation errors
        failFast = true
      }
      
      # Rollback triggers
      triggers = [
        {
          name = "deployment-timeout"
          condition = {
            type = "timeout"
            value = "15m"
          }
          action = "rollback-to-previous"
        },
        {
          name = "health-check-failure"
          condition = {
            type = "health-check"
            failureThreshold = 3
            successThreshold = 1
          }
          action = "rollback-to-known-good"
        },
        {
          name = "manual-trigger"
          condition = {
            type = "annotation"
            key = "stakpak.dev/rollback"
            value = "true"
          }
          action = "rollback-to-specified"
        }
      ]
      
      # Known good state management
      knownGoodState = {
        # Keep last 5 successful deployments
        retention = 5
        # Tag format for known good images
        tagPrefix = "known-good-"
        # Promote after 24h stability
        autoPromote = {
          enabled = true
          stabilityPeriod = "24h"
        }
      }
      
      # Notifications
      notifications = {
        onRollbackStart = {
          slack = {
            webhook = var.slack_webhook_url
            message = "⚠️ Sunkworks Contingency: Starting rollback for {{ .ReleaseName }}"
          }
        }
        onRollbackComplete = {
          slack = {
            webhook = var.slack_webhook_url
            message = "✅ Rollback complete for {{ .ReleaseName }} - reverted to {{ .PreviousVersion }}"
          }
        }
        onRollbackFailed = {
          slack = {
            webhook = var.slack_webhook_url
            message = "❌ CRITICAL: Rollback FAILED for {{ .ReleaseName }} - manual intervention required"
          }
          pagerduty = {
            routingKey = var.pagerduty_routing_key
            severity = "critical"
          }
        }
      }
    }
  })
}

# =============================================================================
# GitHub Actions Workflow for CI/CD
# =============================================================================

resource "local_file" "github_workflow" {
  filename = "${path.module}/generated/.github/workflows/stakpak-build.yaml"
  
  content = yamlencode({
    name = "Stakpak Build Pipeline"
    
    on = {
      push = {
        branches = ["main"]
        paths = [
          "extensions/**",
          "packages/**"
        ]
      }
      pull_request = {
        branches = ["main"]
      }
      workflow_dispatch = {
        inputs = {
          force_rebuild = {
            description = "Force rebuild all artifacts"
            required = false
            default = "false"
          }
        }
      }
    }
    
    env = {
      OCI_REGISTRY        = var.oci_registry
      OCI_REGISTRY_PREFIX = var.oci_registry_prefix
    }
    
    jobs = {
      validate = {
        runs-on = "ubuntu-latest"
        steps = [
          {
            name = "Checkout"
            uses = "actions/checkout@v4"
          },
          {
            name = "Validate Stakpak configs"
            run = <<-EOT
              stakpak validate stakpak-*.yaml
            EOT
          },
          {
            name = "Validate Talos configs"
            run = <<-EOT
              talosctl validate -m metal controlplane.yaml
              talosctl validate -m metal worker.yaml
            EOT
          }
        ]
      }
      
      build = {
        needs = ["validate"]
        runs-on = "ubuntu-latest"
        strategy = {
          matrix = {
            extension = ["spin", "tailscale"]
          }
        }
        steps = [
          {
            name = "Checkout"
            uses = "actions/checkout@v4"
          },
          {
            name = "Set up QEMU"
            uses = "docker/setup-qemu-action@v3"
          },
          {
            name = "Set up Docker Buildx"
            uses = "docker/setup-buildx-action@v3"
          },
          {
            name = "Login to Registry"
            uses = "docker/login-action@v3"
            with = {
              registry = "${{ env.OCI_REGISTRY }}"
              username = "${{ secrets.REGISTRY_USERNAME }}"
              password = "${{ secrets.REGISTRY_PASSWORD }}"
            }
          },
          {
            name = "Build and push extension"
            run = <<-EOT
              stakpak build stakpak-${{ matrix.extension }}.yaml --push
            EOT
          }
        ]
      }
      
      deploy = {
        needs = ["build"]
        runs-on = "ubuntu-latest"
        if = "github.ref == 'refs/heads/main'"
        environment = "production"
        steps = [
          {
            name = "Trigger Flux reconciliation"
            run = <<-EOT
              flux reconcile source git cozystack-deployment
              flux reconcile kustomization cozystack-deployment
            EOT
          },
          {
            name = "Wait for deployment"
            run = <<-EOT
              flux wait kustomization cozystack-deployment --timeout=10m
            EOT
          }
        ]
      }
      
      rollback = {
        if = "failure()"
        needs = ["deploy"]
        runs-on = "ubuntu-latest"
        steps = [
          {
            name = "Trigger Sunkworks Contingency Rollback"
            run = <<-EOT
              stakpak rollback --to-known-good sunkworks-contingency
            EOT
          },
          {
            name = "Notify Sunkworks channel"
            uses = "slackapi/slack-github-action@v1"
            with = {
              payload = <<-EOT
                {
                  "text": "🚨 Sunkworks Contingency Activated!",
                  "blocks": [
                    {
                      "type": "section",
                      "text": {
                        "type": "mrkdwn",
                        "text": "Deployment failed, rolling back to known-good state"
                      }
                    }
                  ]
                }
              EOT
            }
            env = {
              SLACK_WEBHOOK_URL = "${{ secrets.SLACK_WEBHOOK_URL }}"
            }
          }
        ]
      }
    }
  })
}

# =============================================================================
# Outputs
# =============================================================================

output "stakpak_configs" {
  description = "Generated Stakpak configuration files"
  value = {
    spin      = local_file.stakpak_spin_config.filename
    tailscale = local_file.stakpak_tailscale_config.filename
    watcher   = local_file.stakpak_cozystack_watcher.filename
  }
}

output "flux_configs" {
  description = "Generated Flux configuration files"
  value = {
    git_repository  = local_file.flux_gitrepository.filename
    oci_repository  = local_file.flux_ocirepository.filename
    kustomization   = local_file.flux_kustomization.filename
  }
}

output "rollback_config" {
  description = "Rollback strategy configuration"
  value       = local_file.rollback_config.filename
}
