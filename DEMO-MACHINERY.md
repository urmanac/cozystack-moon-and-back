# Demo Machinery & Infrastructure

## What We've Built (Hephy-Builder Approach) 🛠️

Following your guidance to use the **hephy-builder** pattern (formerly kaniko-builder), we've created a complete custom Talos image build system that leverages CozyStack's existing Makefile infrastructure instead of reinventing it.

## Architecture Overview

```
📁 urmanac/cozystack-moon-and-back (This Repo)
├── 🎬 GitHub Actions (.github/workflows/)
│   └── Builds ARM64 Talos images using CozyStack's Make system
├── 🩹 Patches (patches/)  
│   ├── 01-arm64-architecture.patch
│   ├── 02-add-spin-extension.patch
│   └── 03-add-tailscale-extension.patch
├── 🧪 TDG Tests (tests/custom-image/)
│   ├── 01-build-success.sh
│   └── 02-extensions-present.sh  
├── 📚 Documentation (docs/)
│   ├── CUSTOM-TALOS-IMAGES.md
│   ├── MATCHBOX-SERVER-CONFIG.md
│   └── AWS-INFRASTRUCTURE-HANDOFF.md
└── 🎯 Artifacts → GHCR (ghcr.io/urmanac/talos-cozystack-demo)
```

## How It Works (Hephy-Builder Spirit) 

### 1. **Clone & Patch Pattern**
Instead of writing our own Dockerfile, we:
- Clone `cozystack/cozystack` upstream repo
- Apply our patches for ARM64 + Spin + Tailscale
- Run their existing `make talos-metal talos-kernel talos-initramfs` targets
- Package the results as OCI artifacts

### 2. **GitHub Actions Free Tier**
- ✅ Uses CozyStack's battle-tested build system
- ✅ ARM64 builds via QEMU (free)
- ✅ GHCR storage (free for public repos)
- ✅ No custom image maintenance overhead

### 3. **Test-Driven Generation (TDG)**
Following Chanwit's methodology:
- Write tests FIRST ✅
- Generate infrastructure to make tests pass
- Iterate until demo works

## Ready to Hand Off 📋

**For AWS-Capable Claude Agent:**

All the planning is complete! The `AWS-INFRASTRUCTURE-HANDOFF.md` document contains:
- ✅ Complete VPC/subnet specifications
- ✅ Security group configurations  
- ✅ Bastion modification instructions
- ✅ Docker container orchestration
- ✅ Launch template for Talos nodes
- ✅ Test-driven validation approach
- ✅ Budget constraints ($0.10/month)
- ✅ Error recovery procedures

**What's Next:**
1. **You pass the handoff document** to AWS-capable Claude
2. **They implement infrastructure** (4 phases, ~2-3 hours)
3. **We test end-to-end** netboot with custom images
4. **You build slides & demo script** for December 4th

## The Cozystack Speed Run Connection 🏃‍♂️

Yes, I found references to your **Cozystack Speed Runs** in the docs! The YouTube channel [@yebyen/streams](https://youtube.com/@yebyen/streams) with previous demos. This aligns perfectly with:

- **Proven approach**: You've done this before successfully
- **Documented process**: Speed runs provide reference implementations
- **Community validation**: Others can replicate your approach
- **Time-boxed demos**: Perfect for conference presentations

## What Makes This Different 🎯

**Traditional Approach**: 
- Build custom Talos images from scratch
- Maintain our own Dockerfile
- Figure out extension integration
- Debug build issues independently

**Hephy-Builder Approach**:
- ✅ Leverage CozyStack's proven build system
- ✅ Apply minimal patches to existing working code
- ✅ Inherit their extension management
- ✅ Benefit from their ARM64 testing

**The Spirit**: Don't rebuild what exists, integrate it cleverly.

## Success Criteria ✨

**For December 4 Demo:**
- [ ] Custom ARM64 images build in GitHub Actions
- [ ] AWS bastion netboots Talos nodes successfully  
- [ ] SpinKube demo runs on ARM64
- [ ] Total cost < $0.10/month demonstrated
- [ ] Audience thinks: "I could replicate this"

**Stretch Goals:**
- [ ] Flux 2.7 ExternalArtifact features showcased
- [ ] Tailscale mesh between cloud & home lab
- [ ] Live cost monitoring during demo

## Questions Answered 🤔

**Q: Did you understand the hephy-builder concept?**  
A: Yes! Clone remote repo → Apply patches → Run Make commands → Package results. Much smarter than custom Dockerfiles.

**Q: Does this align with the Cozystack Speed Run approach?**  
A: Absolutely. We're building on your proven patterns, just validating them in AWS first before bringing home to ARM64.

**Q: Is this ready for the AWS handoff?**  
A: Yes! The handoff document is complete with specifications, tests, and success criteria. The AWS agent can start implementing immediately.

---

**Ready for your coffee?** ☕  

The AWS handoff document is waiting, and all the demo machinery planning is complete. The infrastructure implementation should take 2-3 hours, then we can test the full flow and start building slides!

*Built with the spirit of Hephaestus, Greek God of Craftsmanship* 🔨