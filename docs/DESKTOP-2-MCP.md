# MCP Tools Enumeration & Testing Plan

## Summary

This document enumerates the available MCP tools and connectors, identifies which endpoints can be reasonably tested, and provides feedback on PR #27.

---

## Available Tools

### 1. Kubernetes MCP Server ✅ (Verified Working)
**Status**: Connected and responsive (ping confirmed in previous session)

| Tool | Description | Testable |
|------|-------------|----------|
| `kubectl_get` | Get/list K8s resources | ✅ Yes |
| `kubectl_describe` | Describe K8s resources | ✅ Yes |
| `kubectl_apply` | Apply YAML manifests | ⚠️ With caution |
| `kubectl_delete` | Delete resources | ⚠️ With caution |
| `kubectl_create` | Create resources | ⚠️ With caution |
| `kubectl_logs` | Get container logs | ✅ Yes |
| `kubectl_scale` | Scale deployments | ⚠️ With caution |
| `kubectl_patch` | Patch resources | ⚠️ With caution |
| `kubectl_rollout` | Manage rollouts | ⚠️ With caution |
| `kubectl_context` | Manage contexts | ✅ Yes |
| `explain_resource` | Get K8s resource docs | ✅ Yes |
| `install_helm_chart` | Install Helm charts | ⚠️ With caution |
| `upgrade_helm_chart` | Upgrade Helm releases | ⚠️ With caution |
| `uninstall_helm_chart` | Uninstall Helm releases | ⚠️ With caution |
| `node_management` | Cordon/drain/uncordon | ⚠️ With caution |
| `port_forward` | Port forwarding | ✅ Yes |
| `stop_port_forward` | Stop port forwards | ✅ Yes |
| `exec_in_pod` | Execute in pods | ⚠️ With caution |
| `list_api_resources` | List API resources | ✅ Yes |
| `kubectl_generic` | Generic kubectl commands | ⚠️ Depends |
| `ping` | Verify connectivity | ✅ Yes |
| `cleanup` | Cleanup managed resources | ✅ Yes |

### 2. AWS MCP Server ⚠️ (Session Token Expired)
**Status**: Reachable but authentication expired

| Tool | Description | Testable |
|------|-------------|----------|
| `suggest_aws_commands` | NL to AWS CLI suggestions | ✅ Yes (no auth needed) |
| `call_aws` | Execute AWS CLI commands | ❌ Requires valid session |

### 3. Web Tools ✅ (Working)
| Tool | Description | Testable |
|------|-------------|----------|
| `web_search` | Search the web | ✅ Yes |
| `web_fetch` | Fetch web page contents | ✅ Yes (with URL restrictions) |

### 4. Artifacts ✅ (Working)
| Tool | Description | Testable |
|------|-------------|----------|
| `artifacts` | Create/update artifacts | ✅ Yes |

---

## Missing/Unavailable Tools

### ❌ Filesystem MCP Tools
**Status**: NOT AVAILABLE in current session

I do not have access to filesystem tools that would allow me to:
- Browse local directories
- Read files from local git repos
- Write files locally

If you have a filesystem MCP server configured, it may not be connected to this session.

### ❌ GitHub Connector
**Status**: NOT AVAILABLE as a direct tool

While you mentioned the GitHub Connector shows as "connected", I do not see any GitHub-specific functions in my available tools list. The tools I would expect to see if GitHub were available:
- `github_get_pull_request`
- `github_list_commits`
- `github_create_comment`
- `github_get_file_contents`
- etc.

**Workaround Used**: I accessed PR #27 via `web_fetch`, which provided the PR description but limited access to diffs and files.

---

## Safe-to-Test Endpoints (No Side Effects)

These tools can be tested without making changes:

| Category | Tool | Test Command |
|----------|------|--------------|
| **Kubernetes** | `ping` | Verify connectivity |
| **Kubernetes** | `kubectl_context` | List/get contexts |
| **Kubernetes** | `kubectl_get` | List pods, namespaces, etc. |
| **Kubernetes** | `list_api_resources` | Show available API resources |
| **Kubernetes** | `explain_resource` | Get documentation |
| **AWS** | `suggest_aws_commands` | Get command suggestions |
| **Web** | `web_search` | Search queries |
| **Web** | `web_fetch` | Fetch public URLs |

---

## PR #27 Feedback

### Pull Request: "Add comprehensive CozyStack deployment and testing documentation"
**Repository**: `urmanac/cozystack-moon-and-back`
**Author**: kingdonb
**Changes**: +1,060 lines, −0 lines

### Documents Added

1. **`docs/guides/AWS-ARM64-COZYSTACK-DEPLOYMENT.md`**
   - AWS ARM64 infrastructure deployment guide
   - Boot-to-Talos approach (Ubuntu → Talos conversion)
   - Claude Desktop MCP integration points

2. **`docs/guides/CROSSPLANE-V2-TESTING.md`**
   - Crossplane v2 testing procedures
   - Testing scope documentation

3. **`docs/guides/OPERATIONAL-PROCEDURES.md`**
   - Operational knowledge from AMD64 home lab
   - Workflow patterns for ARM64 translation

### Architecture Highlights

- **3-layer network architecture** alignment across docs
- **Boot-to-Talos innovation**: Ubuntu cloud-init → Talos download → kexec reboot
- **Registry cache strategy** for IPv6/private VPC constraints
- **Conference demo target**: December 3, 2025 CozySummit

### Assessment

**Strengths:**
- Comprehensive documentation (+1,060 lines is substantial)
- Well-structured with clear MCP integration points
- Supports both manual and automated (Claude Desktop) workflows
- Aligns with moonlander project expansion goals

**Questions/Suggestions (for review):**
1. Are the MCP connector integration points tested with actual Claude Desktop sessions?
2. Does the boot-to-talos approach handle ARM64 Talos images correctly?
3. Are there rollback procedures documented if kexec fails?
4. Consider adding a troubleshooting section for common failure modes

**Overall**: This looks like solid documentation for the CozyStack/ARM64 deployment story. The Claude Desktop automation integration is forward-thinking.

---

## Recommendations

1. **GitHub Connector**: Please verify the GitHub connector is properly configured. I cannot see it in my available tools despite it showing as "connected" in your UI.

2. **Filesystem Access**: If you want me to review local git repos, we'll need to ensure the filesystem MCP server is connected.

3. **AWS Session**: To test AWS commands beyond suggestions, you'll need to refresh the session token.

4. **For Full PR Review**: If you can provide the raw diff or file contents via another method (paste, upload, or fix the GitHub connector), I can provide more detailed code review feedback.
