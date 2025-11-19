# Repository Constellation Overview: CozyStack Moon and Back

## Purpose of This Document

This document maps the constellation of repositories that support the "Home Lab to the Moon and Back" talk and demo for CozySummit Virtual 2025 (December 4). It follows the **Test-Driven Generation (TDG)** methodology created by Chanwit Kaewkasi.

**For the next Claude agent**: Use this as a reference map. Don't rebuild what exists - integrate it. Each repo serves a specific purpose in the ecosystem.

## Demo Strategy & Expected Blockers

**Demo approach**: Speed run showing CozyStack bootstrap through **ClickOps in dashboard**
- **NOT GitOps** - CozyStack currently doesn't depend on Git, only Helm
- **Dashboard → K8s API**: Creates HelmReleases via CozyStack API (K8s API Aggregation Layer)
- **Controlled access**: Each CozyStack API object (e.g., "Kubernetes") creates a HelmRelease with a specific chart. RBAC controls which CozyStack APIs tenants can access - "tenant can create databases but not kuberneteses" via API permissions, not direct HelmRelease access
- **Focus**: ARM64-specific needs, not comprehensive CozyStack installation
- **Show moving parts**: Provision Kubernetes through dashboard if possible

**Current CozyStack architecture**:
- **Embedded Helm Chart repository** in CozyStack installer
- **CozyStack API**: K8s API Aggregation Layer providing controlled abstraction over HelmReleases
- **Security model**: Tenants access CozyStack APIs (not raw HelmReleases) - prevents arbitrary chart installation
- **RBAC integration**: Control which CozyStack resource types tenants can create
- **No Git dependency**: Dashboard calls K8s API directly
- **Future evolution**: May support Git-based infrastructure or OCI for GitLess Flux

**Expected blockers we'll handle gracefully**:
- **Virtualization support**: KubeVirt/virtualization may not work on ARM64
- **Action plan**: Open GitHub issues, link to them, but don't let them block us
- **Fallback**: SpinKube WASM modules will work fine on ARM64 
- **Key insight**: Most CozyStack workloads already work, virtualization is the question mark

**Success criteria**:
- Audience understands **ClickOps → K8s API** workflow (not GitOps)
- ARM64 cluster bootstraps successfully  
- SpinKube demos work (even if virtualization doesn't)
- Blockers are documented, not ignored
- Clear explanation of CozyStack API Aggregation Layer providing controlled abstraction over HelmReleases

---

## Repository Map (By Function)

### 🎯 Primary: Presentation & Demo
**urmanac/cozystack-moon-and-back** - The main event
- **Purpose**: Talk materials, demo infrastructure, live presentation
- **Contains**: Terraform, tests, slides, SpinKube demos
- **Audience**: CozySummit attendees, CozyStack community
- **Integration point**: References all other repos as dependencies
- **Status**: Active development for December 4 deadline

---

### 🏗️ Infrastructure Layer

#### **urmanac/aws-accounts** - Production infrastructure
- **Purpose**: All Urmanac AWS infrastructure (Sandbox account)
- **Contains**: Terraform modules for VPC, ASG, security groups
- **Owner**: Urmanac, LLC (Kingdon Barrett)
- **Current state**: Bastion in public subnet, scheduled 5hrs/day
- **Integration**: Source modules for cozystack-moon-and-back
- **Note**: Don't duplicate - import modules or reference them

**Test for aws-accounts integration:**
```bash
#!/bin/bash
# tests/integration/10-aws-accounts-modules.sh

test_can_import_vpc_module() {
  # GIVEN: aws-accounts repo is accessible
  # WHEN: Terraform init runs in cozystack-moon-and-back
  # THEN: VPC module from aws-accounts imports successfully
  
  cd terraform/
  terraform init
  terraform validate | grep -q "Success"
}

test_bastion_asg_reusable() {
  # The existing ASG/launch template should be parameterized
  # We should be able to:
  # 1. Move it to private subnet
  # 2. Add user data for Docker containers
  # 3. Change static IP assignment
  
  # Check if module accepts these parameters
  grep -q "subnet_id" ../aws-accounts/modules/bastion/variables.tf
  grep -q "user_data" ../aws-accounts/modules/bastion/variables.tf
  grep -q "private_ip" ../aws-accounts/modules/bastion/variables.tf
}

# Run tests
test_can_import_vpc_module && test_bastion_asg_reusable
```

---

### 🚀 GitOps & Flux Layer

#### **kingdon-ci/fleet-infra** - Original Flux bootstrap (possibly deprecated?)
- **Purpose**: Legacy Flux configuration
- **Status**: ⚠️ Unclear if active or superseded by cozy-fleet
- **Action needed**: Operator to confirm canonical status

#### **kingdon-ci/cozy-fleet** - Demo infrastructure GitOps ⭐
- **Purpose**: GitOps management of demo cluster infrastructure (not CozyStack configs)
- **Contains**: Flux controllers, Kustomizations for demo environment
- **Status**: This is THE canonical repo for demo infrastructure
- **Integration**: Bootstrap demo cluster from this repo
- **Important**: CozyStack itself doesn't store configs here - uses K8s API directly
- **Note**: Fleets belong in orgs (kingdon-ci), foundational GitOps principle

**Test for Flux bootstrap:**
```bash
#!/bin/bash
# tests/integration/11-flux-bootstrap.sh

test_cozy_fleet_is_canonical() {
  # GIVEN: cozy-fleet manages demo infrastructure
  # WHEN: Preparing for CozySummit demo
  # THEN: This repo should contain our demo cluster bootstrap
  
  [ -d "../cozy-fleet" ] || {
    echo "REQUIRED: git clone git@github.com:kingdon-ci/cozy-fleet.git"
    return 1
  }
  
  # Contains Flux configs for demo infrastructure, NOT CozyStack HelmReleases
  # CozyStack HelmReleases are created via dashboard → K8s API
  flux_configs=$(find ../cozy-fleet -name "*.yaml" -exec grep -l "flux" {} \; | wc -l)
  [ "$flux_configs" -ge 0 ] # Demo infrastructure configs
}

test_flux_external_artifact_support() {
  # GIVEN: Flux 2.7 with ExternalArtifact feature
  # WHEN: Checking cozy-fleet for OCI artifact references
  # THEN: We could use this to reference pre-built images
  
  # Opportunity: Store Talos images as OCI artifacts
  # Reference them in Flux without rebuilding
  
  grep -r "kind: ExternalArtifact" ../cozy-fleet/ || echo "Not yet using ExternalArtifacts - opportunity!"
}

# Run tests
test_cozy_fleet_is_canonical && test_flux_external_artifact_support
```

---

### 🎬 Demo & Application Layer

#### **kingdonb/cozystack-talm-demo** - CozyStack state backups & Speed Runs
- **Purpose**: Makefile-based backups of CozyStack state, YouTube demo links
- **Contains**: HelmRelease snapshots (via backup Makefile), Speed Run videos
- **YouTube**: youtube.com/@yebyen/streams
- **Integration**: Reference for understanding CozyStack structure, not active workflow
- **Note**: HelmReleases here are backups, not source - CozyStack uses K8s API directly

**Demo reference test:**
```bash
#!/bin/bash
# tests/integration/12-talm-demo-references.sh

test_can_reuse_helm_releases() {
  # GIVEN: cozystack-talm-demo has working HelmReleases
  # WHEN: Building new demo for talk
  # THEN: We should reference/copy existing validated configs
  
  helm_releases=$(find ../cozystack-talm-demo -name "*.yaml" -type f | grep -i helmrelease | wc -l)
  
  [ "$helm_releases" -gt 0 ]
}

test_youtube_links_documented() {
  # Each Speed Run should be documented with YouTube link
  # This helps validate our demo matches proven working setups
  
  grep -r "youtube.com" ../cozystack-talm-demo/README.md || \
    echo "Add YouTube links to document successful runs"
}

# Run tests
test_can_reuse_helm_releases && test_youtube_links_documented
```

---

### 🔧 Tool & Utility Layer

#### **kingdon-ci/kaniko-builder** - Container image building
- **Purpose**: Build container images (kaniko-based)
- **Contains**: Pre-configured build pipelines
- **Integration**: Use for custom Talos image builds
- **DON'T**: Rebuild this - just use it as a dependency
- **Use case**: Build Talos images with Spin + Tailscale extensions

**Image building test:**
```bash
#!/bin/bash
# tests/integration/13-kaniko-builder-available.sh

test_kaniko_builder_accessible() {
  # GIVEN: kaniko-builder repo exists
  # WHEN: We need to build custom Talos image
  # THEN: We should reference existing build pipeline
  
  # Check if repo is cloned locally or accessible via Git
  [ -d "../kaniko-builder" ] || git ls-remote https://github.com/kingdon-ci/kaniko-builder.git
}

test_custom_talos_image_buildable() {
  # GIVEN: kaniko-builder pipeline
  # WHEN: Adding Spin + Tailscale extensions
  # THEN: Build process should be documented
  
  # This is a placeholder for actual build documentation
  echo "Document: How to build custom Talos image with extensions"
  echo "1. Start with base Talos image"
  echo "2. Add Spin runtime extension"
  echo "3. Add Tailscale extension"
  echo "4. Use kaniko-builder to create OCI artifact"
  echo "5. Store in registry or as Flux ExternalArtifact"
  
  true # Manual verification
}

# Run tests
test_kaniko_builder_accessible && test_custom_talos_image_buildable
```

#### **kingdon-ci/time-tracker** - Time tracking utilities
- **Purpose**: Track time spent on tasks/projects
- **Contains**: Time tracking integrations
- **Integration**: If demo needs time tracking, use this
- **DON'T**: Build from scratch
- **Possible use**: Track experiment session durations for cost analysis

**Time tracking test:**
```bash
#!/bin/bash
# tests/integration/14-time-tracker-optional.sh

test_time_tracker_available_if_needed() {
  # GIVEN: time-tracker repo exists
  # WHEN: We want to track demo session durations
  # THEN: Integration should be straightforward
  
  # This is optional for the demo
  # But could be useful for cost analysis:
  # "We ran 5 experiments, 2.5 hours each, cost = $X"
  
  [ -d "../time-tracker" ] || echo "Optional: Clone if needed for session tracking"
  true # Not critical path
}

# Run test
test_time_tracker_available_if_needed
```

#### **kingdonb/mecris** - Dog-walking MCP server
- **Purpose**: MCP server for dog walking (personal project)
- **Contains**: Example MCP server implementation
- **Integration**: Reference architecture for building other MCP servers
- **Use case**: If we need custom MCP server for demo orchestration
- **Note**: Mentioned as "easier to build at home than at work"

**MCP reference test:**
```bash
#!/bin/bash
# tests/integration/15-mecris-mcp-reference.sh

test_mecris_as_mcp_example() {
  # GIVEN: mecris is a working MCP server
  # WHEN: Building new MCP servers for demo
  # THEN: Can reference implementation patterns
  
  # Example: If we need a custom MCP server to:
  # - Orchestrate Talos node launches
  # - Monitor experiment costs in real-time
  # - Automate demo script execution
  
  [ -d "../mecris" ] || echo "Reference: MCP server implementation patterns"
  true # Reference only
}

# Run test
test_mecris_as_mcp_example
```

---

### 🤖 AI Infrastructure Layer

#### **kingdon-ci/noclaude** - Claude Code with OpenAI backend
- **Purpose**: Run Claude Code interface with OpenAI/litellm backend
- **Contains**: claude-code-proxy + litellm configuration
- **Use case**: Cheaper AI operations for simple tasks
- **Status**: Local clone, not yet operationalized in cluster
- **Future**: Run inside Kubernetes cluster for optimized inference

**AI infrastructure test:**
```bash
#!/bin/bash
# tests/integration/16-noclaude-ai-backend.sh

test_noclaude_alternative_backend() {
  # GIVEN: Government work constraints on AI dependencies
  # WHEN: Need AI assistance but can't rely solely on Anthropic
  # THEN: noclaude provides OpenAI/self-hosted alternative
  
  # This isn't critical for December 4 demo
  # But represents future direction:
  # "If you're running a cluster, host your own models"
  
  echo "Future: Deploy noclaude in CozyStack cluster"
  echo "- Run litellm for model routing"
  echo "- Host claude-code-proxy"
  echo "- Fine-tune models for infrastructure tasks"
  
  true # Aspirational test
}

test_cluster_hosted_ai_ready() {
  # GIVEN: CozyStack cluster operational
  # WHEN: Evaluating AI inference capabilities
  # THEN: KubeVirt could host GPU VMs for model serving
  
  # This is a stretch goal for the talk
  # "It's 2025 - if you have a cluster, use it for AI"
  
  echo "Stretch goal: Demo AI inference on CozyStack"
  true # Not blocking demo
}

# Run tests
test_noclaude_alternative_backend && test_cluster_hosted_ai_ready
```

#### **chanwit/tdg** - Test-Driven Generation skill
- **Purpose**: Open source TDG methodology and Claude skill
- **Credit**: Chanwit Kaewkasi (TDG methodology creator)
- **Integration**: This entire document follows TDG principles
- **Reference**: https://chanwit.medium.com/i-was-wrong-about-test-driven-generation-and-i-couldnt-be-happier-9942b6f09502
- **License**: Open source (check repo for specific license)

**TDG methodology test:**
```bash
#!/bin/bash
# tests/integration/17-tdg-compliance.sh

test_all_work_follows_tdg() {
  # GIVEN: TDG methodology from Chanwit
  # WHEN: Generating code for this project
  # THEN: Tests should be written BEFORE implementation
  
  # Every artifact should have corresponding test
  # Tests fail first, then we generate code to pass them
  
  test_count=$(find tests/ -name "*.sh" | wc -l)
  [ "$test_count" -ge 17 ] # At least this many integration tests
}

test_tdg_documented() {
  # TDG methodology should be credited and explained
  grep -q "Chanwit" docs/TDG-PLAN.md
  grep -q "Test-Driven Generation" README.md
}

# Run tests
test_all_work_follows_tdg && test_tdg_documented
```

---

## Repository Dependency Graph

```
cozystack-moon-and-back (MAIN)
├── aws-accounts (infrastructure modules)
│   └── terraform/modules/
│       ├── vpc
│       ├── bastion-asg
│       └── security-groups
│
├── cozy-fleet (GitOps - canonical?)
│   ├── flux-system/
│   └── clusters/demo/
│       └── HelmReleases
│
├── cozystack-talm-demo (reference configs)
│   └── Speed Run examples
│       └── YouTube: @yebyen/streams
│
├── kaniko-builder (image building)
│   └── Build custom Talos images
│       ├── + Spin extension
│       └── + Tailscale extension
│
├── time-tracker (optional)
│   └── Session duration tracking
│
├── mecris (reference)
│   └── MCP server patterns
│
├── noclaude (future)
│   └── Self-hosted AI inference
│
└── chanwit/tdg (methodology)
    └── Open source TDG skill
```

---

## Integration Tests: Cross-Repository Dependencies

### Test 18: Module Imports Work
```bash
#!/bin/bash
# tests/integration/18-module-imports.sh

test_terraform_modules_importable() {
  # GIVEN: Multiple Terraform repos
  # WHEN: cozystack-moon-and-back references aws-accounts modules
  # THEN: Terraform init succeeds
  
  cd terraform/
  
  # Check if we're using path references or Git sources
  grep -r "source.*aws-accounts" . || echo "Add module references to aws-accounts"
  
  terraform init -backend=false # Don't need real backend for validation
  terraform validate
}

test_no_duplicate_resources() {
  # GIVEN: Shared modules between repos
  # WHEN: Multiple repos define same resources
  # THEN: Should reference, not duplicate
  
  # Example: VPC should be defined once, imported elsewhere
  # Don't create multiple VPC definitions
  
  echo "Verify: VPC defined in aws-accounts, imported in moon-and-back"
  true # Manual verification
}

# Run tests
test_terraform_modules_importable && test_no_duplicate_resources
```

### Test 19: Flux ExternalArtifact Integration
```bash
#!/bin/bash
# tests/integration/19-flux-external-artifacts.sh

test_flux_27_features_available() {
  # GIVEN: Flux 2.7 introduces ExternalArtifact
  # WHEN: We have pre-built Talos images
  # THEN: Can reference them without rebuilding
  
  # This is a NEW feature to explore for the demo
  # Perfect opportunity to show cutting-edge Flux capabilities
  
  kubectl get crd | grep -q "externalsources" || \
    echo "Install Flux 2.7+ with ExternalArtifact support"
}

test_talos_image_as_oci_artifact() {
  # GIVEN: Custom Talos image built via kaniko-builder
  # WHEN: Storing in OCI registry
  # THEN: Flux can reference it as ExternalArtifact
  
  # Example ExternalArtifact for Talos image:
  cat <<EOF
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: ExternalSource
metadata:
  name: talos-cozystack-custom
spec:
  url: oci://ghcr.io/kingdon-ci/talos-cozystack
  tag: v1.9.0-spin-tailscale
EOF
  
  # This would be GREAT demo content:
  # "Here's how we distribute custom Talos images with Flux 2.7"
  
  true # Design test, not yet implemented
}

# Run tests
test_flux_27_features_available && test_talos_image_as_oci_artifact
```

### Test 20: Demo Script Completeness
```bash
#!/bin/bash
# tests/integration/20-demo-script-complete.sh

test_all_repos_referenced_in_slides() {
  # GIVEN: Constellation of 8+ repos
  # WHEN: Building talk slides
  # THEN: Should credit and explain each repo's role
  
  slides_dir="slides/"
  
  # Each repo should get a mention
  repos=(
    "aws-accounts"
    "cozy-fleet"
    "cozystack-talm-demo"
    "kaniko-builder"
    "noclaude"
    "chanwit/tdg"
  )
  
  for repo in "${repos[@]}"; do
    grep -r "$repo" "$slides_dir" || \
      echo "Add $repo to slides with context"
  done
}

test_demo_script_executable() {
  # GIVEN: Live demo during talk
  # WHEN: Following demo script
  # THEN: Each step should be validated
  
  # Demo script should include:
  # 1. Show home lab (running hot)
  # 2. Show AWS cost ($0.04/month)
  # 3. Launch Talos node
  # 4. Netboot process (< 5 min)
  # 5. CozyStack dashboard
  # 6. Deploy SpinKube app
  # 7. Show it running on ARM64
  # 8. Terminate node (back to $0.04)
  
  [ -f "docs/DEMO-SCRIPT.md" ] || echo "Create detailed demo script"
}

test_fallback_plan_documented() {
  # GIVEN: Live demos can fail
  # WHEN: AWS has issues or demo breaks
  # THEN: Home lab fallback ready
  
  # Fallback: Demo from home lab
  # Still show: Cost analysis, architecture diagrams
  # Message: "This is why we validate in cloud first"
  
  [ -f "docs/FALLBACK-PLAN.md" ] || echo "Document fallback strategy"
}

# Run tests
test_all_repos_referenced_in_slides && \
test_demo_script_executable && \
test_fallback_plan_documented
```

---

## Repository Health Metrics

### Test 21: Documentation Quality
```bash
#!/bin/bash
# tests/integration/21-documentation-quality.sh

test_readme_in_each_repo() {
  # GIVEN: 8 repositories in constellation
  # WHEN: New contributor encounters project
  # THEN: Each repo should have clear README
  
  repos=(
    "../aws-accounts"
    "../cozy-fleet"
    "../cozystack-talm-demo"
    "../kaniko-builder"
    "../time-tracker"
    "../mecris"
    "../noclaude"
  )
  
  for repo in "${repos[@]}"; do
    [ -f "$repo/README.md" ] || echo "Missing README in $repo"
  done
}

test_cross_references_documented() {
  # Each repo should reference related repos
  # Example: aws-accounts README should mention cozystack-moon-and-back
  
  grep -r "cozystack-moon-and-back" ../aws-accounts/README.md || \
    echo "Add cross-reference to presentation repo"
}

# Run tests
test_readme_in_each_repo && test_cross_references_documented
```

---

## Priority Integration Matrix

| Repository | Critical for Demo? | Integration Effort | Status |
|------------|-------------------|-------------------|---------|
| aws-accounts | ✅ YES | Medium (modify existing) | Active |
| cozy-fleet | ✅ YES | Low (bootstrap only) | Need to confirm canonical |
| cozystack-talm-demo | ⚠️ HELPFUL | Low (reference only) | Reference |
| kaniko-builder | ⚠️ HELPFUL | Medium (custom image) | Stretch goal |
| time-tracker | ❌ OPTIONAL | Low | Nice to have |
| mecris | ❌ REFERENCE | None | Inspiration only |
| noclaude | ❌ FUTURE | High | Post-demo |
| chanwit/tdg | ✅ METHODOLOGY | None | Credit in docs |

---

## Next Actions for Claude Agent

### Immediate (This Week)
1. **Confirm canonical Flux repo** - Is it cozy-fleet or fleet-infra?
2. **Import aws-accounts modules** - Don't duplicate Terraform
3. **Reference talm-demo configs** - Don't rebuild HelmReleases from scratch

### Near-term (Before December 4)
4. **Plan Flux 2.7 ExternalArtifact demo** - Show off new features!
5. **Document custom Talos image build** - Using kaniko-builder
6. **Create demo script** - With fallback to home lab

### Post-demo (Future)
7. **Operationalize noclaude** - Run in CozyStack cluster
8. **Add time-tracker integration** - For cost/session analysis
9. **Build more MCP servers** - Using mecris patterns

---

## Success Criteria

**For December 4 demo:**
- [ ] All repos properly credited in slides
- [ ] No duplicated code between repos
- [ ] Clear README.md in cozystack-moon-and-back explaining constellation
- [ ] Demo works OR fallback plan executes smoothly
- [ ] Audience understands: "Don't rebuild, integrate"
- [ ] TDG methodology credited to Chanwit

**Post-demo success:**
- [ ] Community can replicate using these repos
- [ ] Other talks reference this constellation model
- [ ] Repos continue to evolve independently
- [ ] Integration tests remain passing

---

## Handoff Notes for Next Claude Agent

**Repository philosophy:**
- **DON'T duplicate** - Reference existing code
- **DON'T rebuild** - Use kaniko-builder, time-tracker as-is
- **DO integrate** - Import modules, reference configs
- **DO credit** - Chanwit for TDG, all repos in slides

**Key decisions needed:**
1. Which Flux repo is canonical? (operator to confirm)
2. Should we build custom Talos image or use stock? (stretch goal)
3. Where to store demo artifacts? (OCI registry vs. Git)

**When operator returns:**
"I've mapped all 8+ repositories in your constellation. The integration tests show we should import aws-accounts modules rather than duplicate, reference talm-demo configs, and use Flux 2.7 ExternalArtifacts for custom Talos images. Which repo should I focus on first?"

---

## Remote Repository Links

**Core repositories accessed during this analysis:**

- **aws-accounts** - `git@github.com:urmanac/aws-accounts.git`
  - Status: Validated modules for Security Groups, VPCs, Route Tables
  - Integration: Import terraform modules instead of duplicating
  - Key modules: vpc, security_groups, route_tables
  - Branch: main

- **kubeconfig-ca-fetch** - `git@github.com:kingdon-ci/kubeconfig-ca-fetch.git`  
  - Status: Verified kubeconfig download automation
  - Integration: Use as-is for cluster access
  - Purpose: Fetch kubeconfigs with CA bundle verification
  - Branch: main

- **moonlander** - `git@github.com:kingdon-ci/moonlander.git`
  - Status: Confirmed Terraform AWS provider setup
  - Integration: Reference provider configurations
  - Purpose: AWS infrastructure patterns and provider setup
  - Branch: main

---

*Document created: 2025-11-16*  
*Methodology: Test-Driven Generation (TDG) by Chanwit Kaewkasi*  
*Purpose: Map repository constellation for CozySummit talk*  
*Target: December 4, 2025 - 18 days remaining*
