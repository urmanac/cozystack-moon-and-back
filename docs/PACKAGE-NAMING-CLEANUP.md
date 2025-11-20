# Package Naming Cleanup Proposal

## Current Package Names (Ugly! 😱)
```
talos-cozystack-spin-only/matchbox
talos-cozystack-spin-tailscale/matchbox
talos-cozystack-spin-tailscale/talos
talos-cozystack-spin-only/talos
```

**Problems:**
- ❌ Repetitive "talos-cozystack" prefix
- ❌ Line wrapping in GitHub UI 
- ❌ Hard to distinguish node types at a glance
- ❌ "matchbox" packages not needed for AWS (only home lab PXE)

## Proposed Clean Names ✨

### Option 1: Minimal & Clean
```
cozystack/gateway          # Talos + Spin + Tailscale
cozystack/compute          # Talos + Spin only  
cozystack/matchbox         # PXE server (home lab only)
```

### Option 2: Descriptive
```
cozystack/talos-gateway    # Talos gateway node
cozystack/talos-compute    # Talos compute node
cozystack/pxe-server       # Matchbox for home lab
```

### Option 3: Role-Based (Matches ADR-004)
```
cozystack/gateway-node     # Role: Tailscale subnet router
cozystack/compute-node     # Role: Spin workload runner
cozystack/netboot-server   # Role: Home lab PXE/DHCP
```

## Benefits of Cleanup

✅ **GitHub UI**: No more ugly line wrapping  
✅ **Clarity**: Obvious node roles at a glance  
✅ **Consistency**: Matches ADR-004 role terminology  
✅ **Simplicity**: Remove redundant "talos-cozystack" prefix

## Implementation

**Update GitHub Actions workflow:**
- Change `REGISTRY` and image tags
- Update Dockerfile `LABEL` metadata
- Rebuild and push with new names

**Update Documentation:**
- All references to old package names
- boot-to-talos OCI image URIs
- Test suite expected image names

## Recommendation

**Go with Option 3**: `cozystack/gateway-node`, `cozystack/compute-node`, `cozystack/netboot-server`

**Why**: Matches ADR-004 role-based architecture, clearest for demo audiences, shortest names for GitHub UI.

---

*Proposal: Fix the package names before December 4 demo!* 🚀