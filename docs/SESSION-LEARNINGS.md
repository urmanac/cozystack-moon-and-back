# CozyStack ARM64 + Extensions: Learnings and Architecture

## Session Date: November 16, 2025

### Key Discoveries

#### TDG Methodology Application
- **Critical Insight**: Tests should define requirements FIRST, then implementation follows
- **Mistake Made**: Initially implemented features then tried to retrofit tests
- **Correction**: User guided proper TDG approach where failing tests drive implementation
- **Tool Chain**: TDG tests use `crane export` for FROM scratch containers, not `docker run`

#### Upstream CozyStack Structure
- **Canonical Image**: `ghcr.io/cozystack/cozystack/talos:v1.11.3`
- **Architecture**: Standard Talos installer image with full filesystem
- **Our Goal**: ARM64 version + Spin WebAssembly + Tailscale extensions
- **Asset Generation**: Upstream uses `make assets` target creating files in `_out/assets/`

#### Extension Loading Constraints
- **Critical Constraint**: Talos loads ALL present extensions, failures occur if config missing
- **Architecture Decision**: Need TWO separate images:
  1. **Spin-only**: For regular worker nodes
  2. **Tailscale+Spin**: For subnet router node only
- **Rationale**: Homogeneous clusters need uniform extension sets per node type
- **Network Architecture**: Single tailscale node acts as subnet router for pod/service access

#### CI/CD Pipeline Issues
- **Container Type**: FROM scratch containers can't execute shell commands
- **Testing Method**: Use `crane export | tar -tf -` for inspection
- **Current Issue**: demo-stable contains OLD custom build (commit 3149374), not upstream integration
- **Asset Structure**: Current workflow creates flat structure, need proper boot/ organization

#### GitHub Token Limitations
- **Auth Constraint**: Limited GitHub API access for repository updates
- **Workaround**: Use git commit/push instead of direct API calls
- **Branch Strategy**: Work on upstream-build-system branch

### Architecture Requirements

#### Extension Strategy
```
┌─────────────────────┐    ┌─────────────────────┐
│   Worker Nodes      │    │   Router Node       │
│   (spin-only)       │    │   (tailscale+spin)  │
├─────────────────────┤    ├─────────────────────┤
│ • Spin WebAssembly  │    │ • Spin WebAssembly  │
│ • No Tailscale      │    │ • Tailscale VPN     │
│ • Homogeneous       │    │ • Subnet Router     │
└─────────────────────┘    └─────────────────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │   External      │
                     │   Access via    │
                     │   Tailscale     │
                     └─────────────────┘
```

#### Asset Organization
```
Expected Structure (from TDG test):
assets/talos/arm64/
├── boot/
│   ├── vmlinuz
│   └── initramfs.xz
├── checksums.sha256
└── validation/
    └── build-report.txt

Current Structure (from old build):
assets/talos/arm64/
├── vmlinuz
├── vmlinuz.sha256
├── initramfs.xz
└── initramfs.xz.sha256
```

### Immediate Actions Required

1. **Fix TDG Test**: Update expectations to match upstream installer structure
2. **Dual Images**: Create workflow variants for spin-only vs tailscale+spin
3. **Asset Structure**: Align with upstream conventions, not arbitrary custom structure
4. **Testing**: Implement crane-based testing for scratch containers
5. **Documentation**: Complete this analysis before potential session end

### Technical Context

#### CozyStack Integration
- **Upstream Repo**: https://github.com/cozystack/cozystack
- **Target**: CozySummit Virtual 2025 demo
- **ARM64 Focus**: Custom Talos images for CozyStack platform
- **CNCF Context**: CozyStack is CNCF sandbox project

#### Build System Evolution
- **Phase 1** (commit 3149374): Custom build system (current demo-stable)
- **Phase 2** (current): Upstream integration with proper Makefile targets
- **Phase 3** (planned): Dual extension variants for heterogeneous clusters

### Notes for Continuation

If this session ends abruptly:
1. Current branch `upstream-build-system` has in-progress crane fixes
2. TDG test needs updating to match upstream structure expectations
3. Workflow needs dual-image strategy implementation
4. Key insight: Extension loading constraint requires architectural split
5. All changes should be driven by TDG tests, not implemented then tested

**Status**: Deep architectural understanding achieved, ready for proper implementation following TDG methodology.

---

📍 **Related**: [🧪 TDG Implementation Story](TDG-PLAN.md) | [📚 Documentation Hub](README.md)