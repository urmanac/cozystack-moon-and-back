# Live Fire Test Instructions: ARM64 Talos Single-Node Deployment

## Status: READY FOR EXECUTION ✅

**Build Artifacts Available:**
- **Talos Image**: `ghcr.io/urmanac/talos-cozystack-demo:v1.11.5-v0.38.0-alpha.2-arm64` 
- **Matchbox Server**: `ghcr.io/urmanac/talos-cozystack-demo/matchbox:v1.11.5-v0.38.0-alpha.2`
- **Architecture**: ARM64 with Spin + Tailscale extensions
- **Validation**: ✅ ARM64 architecture confirmed via manifest inspection

---

## PART 1: Current State & Environment (For Admin Review)

### Infrastructure Status
- **✅ Bastion Host**: Online and accessible via SSH
- **✅ Network**: VPC and subnets configured for single-node deployment
- **❌ Talos Node**: No physical/virtual ARM64 node deployed yet
- **❌ Matchbox Server**: Not running (needs deployment on bastion)

### Authentication Context
- **Session**: Admin currently SSH'd into bastion host
- **MFA**: Session token available for handoff to Claude Desktop
- **Permissions**: Full AWS and bastion access established

### Build Pipeline Results
Our GitHub Actions build on native ARM64 runners has produced:

1. **Native ARM64 Talos Images**
   - Built with upstream CozyStack methodology
   - Includes Spin (WebAssembly) + Tailscale (subnet router) extensions  
   - Validates as genuine ARM64 (no cross-compilation issues)

2. **Secure Matchbox Server**
   - Updated to `v0.11.0-243-gd9e0327a-arm64` (no CVEs)
   - Contains ARM64 kernel + initramfs for PXE boot
   - iPXE architecture detection for ARM64 compatibility

---

## PART 2: Execution Instructions (For Claude Desktop)

### Overview
You will help deploy and test our custom ARM64 Talos build in a live single-node environment. The admin has prepared the infrastructure and built the images - your job is to orchestrate the deployment.

### Prerequisites Confirmed
- [x] Admin SSH'd into bastion host  
- [x] MFA session token provided
- [x] ARM64 Talos images built and validated
- [x] Matchbox server image ready
- [x] Network infrastructure configured

### Step 1: Deploy Matchbox Server on Bastion

**Purpose**: Set up PXE boot server to serve ARM64 Talos images

```bash
# Pull the matchbox server image
docker pull ghcr.io/urmanac/talos-cozystack-demo/matchbox:v1.11.5-v0.38.0-alpha.2

# Create matchbox data directory
sudo mkdir -p /var/lib/matchbox/{assets,groups,profiles,ignition}
sudo chown -R $USER:$USER /var/lib/matchbox

# Start matchbox server
docker run -d \
  --name matchbox \
  --net host \
  -p 8080:8080 \
  -v /var/lib/matchbox:/var/lib/matchbox:Z \
  ghcr.io/urmanac/talos-cozystack-demo/matchbox:v1.11.5-v0.38.0-alpha.2 \
  -address=0.0.0.0:8080 \
  -log-level=debug

# Verify matchbox is serving
curl http://localhost:8080/
```

**Expected**: Matchbox web interface accessible, ARM64 assets available

### Step 2: Validate ARM64 Boot Assets

**Purpose**: Confirm ARM64 kernel and initramfs are properly served

```bash
# Check available assets
curl http://localhost:8080/assets/

# Verify ARM64 kernel
curl -I http://localhost:8080/assets/vmlinuz
# Should show ARM64 kernel file

# Verify ARM64 initramfs  
curl -I http://localhost:8080/assets/initramfs.xz
# Should show ARM64 initramfs file

# Check matchbox profiles
curl http://localhost:8080/profiles
```

**Expected**: ARM64 boot assets properly served via HTTP

### Step 3: Configure iPXE Boot Profile

**Purpose**: Set up ARM64-specific boot configuration

```bash
# Create ARM64 boot profile
cat > /var/lib/matchbox/profiles/talos-arm64.json << 'EOF'
{
  "id": "talos-arm64", 
  "name": "Talos ARM64 with Spin+Tailscale",
  "boot": {
    "kernel": "/assets/vmlinuz",
    "initrd": ["/assets/initramfs.xz"],
    "args": [
      "talos.platform=metal",
      "talos.config=http://{{.request.host}}/ignition?uuid={{.request.uuid}}&mac={{.request.mac}}",
      "console=tty0",
      "console=ttyS0,115200"
    ]
  },
  "ignition_id": "talos-worker.ign"
}
EOF

# Create machine group (adjust MAC as needed)
cat > /var/lib/matchbox/groups/default.json << 'EOF'
{
  "id": "default",
  "name": "Default ARM64 Talos",
  "profile": "talos-arm64",
  "selector": {
    "arch": "arm64"
  }
}
EOF
```

### Step 4: Prepare Talos Configuration

**Purpose**: Generate machine configuration for single-node cluster

```bash
# Install talosctl (ARM64 version)
curl -sL https://talos.dev/install | sh
sudo mv talosctl /usr/local/bin/

# Generate machine configuration  
talosctl gen config talos-demo https://YOUR_BASTION_IP:6443 \
  --install-image ghcr.io/urmanac/talos-cozystack-demo:v1.11.5-v0.38.0-alpha.2-arm64

# Place worker config for matchbox
cp worker.yaml /var/lib/matchbox/ignition/talos-worker.ign
```

### Step 5: Boot ARM64 Node

**Purpose**: PXE boot the first Talos node with custom ARM64 image

```bash
# If using QEMU for testing (adjust for real hardware):
qemu-system-aarch64 \
  -machine virt,gic-version=3 \
  -cpu cortex-a57 \
  -smp 2 \
  -m 4096 \
  -netdev user,id=net0,tftp=/var/lib/matchbox,bootfile=undionly.kpxe \
  -device virtio-net-pci,netdev=net0 \
  -boot n

# For physical ARM64 hardware:
# 1. Configure BIOS/UEFI for PXE boot
# 2. Set network boot priority
# 3. Point to bastion IP as PXE server
# 4. Power on and monitor boot process
```

### Step 6: Validate Deployment

**Purpose**: Confirm successful Talos installation with extensions

```bash
# Wait for node to boot and install
# Monitor logs
docker logs -f matchbox

# Once installed, connect to node
talosctl config endpoint YOUR_NODE_IP
talosctl kubeconfig .

# Validate Spin extension
kubectl get pods -n kube-system | grep spin

# Validate Tailscale extension  
talosctl -n YOUR_NODE_IP get extensions
# Should show both spin and tailscale loaded

# Test cluster functionality
kubectl get nodes -o wide
# Should show ARM64 architecture
```

### Step 7: Test Custom Extensions

**Purpose**: Verify Spin and Tailscale extensions work correctly

```bash
# Test Spin (WebAssembly runtime)
# Deploy a sample Wasm workload
kubectl apply -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wasm-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wasm-test
  template:
    metadata:
      labels:
        app: wasm-test
    spec:
      runtimeClassName: wasmtime-spin
      containers:
      - name: wasm-app
        image: ghcr.io/spinkube/containerd-shim-spin/examples/spin-rust-hello:v0.13.0
EOF

# Test Tailscale connectivity
talosctl -n YOUR_NODE_IP get services
# Check for tailscale daemon

# Verify both extensions in system
talosctl -n YOUR_NODE_IP get extensions | grep -E "(spin|tailscale)"
```

### Success Criteria

**✅ Deployment Success Indicators:**
- [ ] Matchbox server responds on port 8080
- [ ] ARM64 boot assets served correctly  
- [ ] Node PXE boots from custom image
- [ ] Talos installs with ARM64 architecture
- [ ] Kubernetes cluster becomes ready
- [ ] Spin extension loads and accepts Wasm workloads
- [ ] Tailscale extension provides subnet router connectivity

**🚨 Troubleshooting Notes:**
- **PXE Boot Fails**: Check network config, DHCP, and matchbox logs
- **Wrong Architecture**: Verify ARM64 kernel/initramfs in assets  
- **Extension Missing**: Check Talos image build included extensions
- **Network Issues**: Validate bastion networking and security groups

### Handoff Complete
Upon successful deployment, you'll have demonstrated:
1. **Custom ARM64 Talos build** working on real hardware
2. **Upstream CozyStack compatibility** with extension methodology  
3. **PXE infrastructure** ready for multi-node expansion
4. **WebAssembly + subnet router** capabilities validated

**Next Steps**: Expand to multi-node cluster using same methodology.

---

## Emergency Contacts & Resources

- **GitHub Repository**: https://github.com/urmanac/cozystack-moon-and-back
- **ADR Documentation**: `docs/ADRs/` for methodology details
- **Patch Validation**: Use `./validate-patch.sh` for any changes
- **Build Pipeline**: Monitor at GitHub Actions for image updates

**Note**: This deployment validates the complete TDG (Test-Driven Generation) methodology for custom Talos builds with upstream compatibility.