#!/usr/bin/env bash
# talos-direct-test.sh - Boot directly from Talos AMI, configure post-boot
set -eo pipefail

# Configuration
REGION="eu-west-1"
VPC_ID="vpc-04af837e642c001c6"
SECURITY_GROUP="sg-0e6b4a78092854897"
REGISTRY_CACHE="10.10.1.100:5054"
CUSTOM_TALOS_IMAGE="ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/talos:latest"

# Official Talos v1.11.5 ARM64 AMI
TALOS_AMI="ami-07898be81f2028262"

echo "🚀 Testing direct Talos AMI approach..."
echo "📍 VPC: $VPC_ID"
echo "🔒 Security Group: $SECURITY_GROUP" 
echo "📦 Registry Cache: $REGISTRY_CACHE"
echo "🐧 Custom Talos: $CUSTOM_TALOS_IMAGE"
echo "📀 Talos AMI: $TALOS_AMI"

# Create instance with TWO volumes: boot + storage
echo "🏗️ Creating Talos node with dual storage..."

INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id "$TALOS_AMI" \
  --instance-type c7g.large \
  --security-group-ids $SECURITY_GROUP \
  --subnet-id subnet-07a140ab2b20bf89b \
  --private-ip-address 10.10.1.108 \
  --ipv6-address-count 1 \
  --block-device-mappings '[
    {
      "DeviceName": "/dev/xvda",
      "Ebs": {
        "VolumeSize": 20,
        "VolumeType": "gp3",
        "DeleteOnTermination": true
      }
    },
    {
      "DeviceName": "/dev/xvdb", 
      "Ebs": {
        "VolumeSize": 100,
        "VolumeType": "gp3",
        "DeleteOnTermination": true
      }
    }
  ]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=talos-direct-01}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ Created Talos instance: $INSTANCE_ID"

# Wait for instance to be running
echo "⏳ Waiting for instance to start..."
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID

# Get the instance's IPv6 address
IPV6_ADDRESS=$(aws ec2 describe-instances \
  --region $REGION \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Ipv6Addresses[0].Ipv6Address' \
  --output text)

echo "🌐 Instance IPv6: $IPV6_ADDRESS"

# Generate Talos config for this specific node
echo "📝 Generating Talos configuration..."
mkdir -p talos-config

# Create machine config with our custom image and registry cache
cat > talos-config/controlplane.yaml << EOF
version: v1alpha1
debug: false
persist: true
machine:
  type: controlplane
  token: $(openssl rand -base64 32)
  ca:
    crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...  # Generate real cert
    key: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVkt...  # Generate real key
  certSANs:
    - $IPV6_ADDRESS
    - 10.10.1.108
  kubelet:
    image: ghcr.io/siderolabs/kubelet:v1.31.3
    defaultRuntimeSeccompProfileEnabled: true
    disableManifestsDirectory: true
    registerWithTaints:
      - effect: NoSchedule
        key: node-role.kubernetes.io/control-plane
  network:
    hostname: talos-direct-01
    interfaces:
      - interface: eth0
        dhcp: true
        dhcpOptions:
          ipv4: true
          ipv6: true
  install:
    disk: /dev/xvda
    image: $CUSTOM_TALOS_IMAGE
    wipe: false
  registries:
    mirrors:
      docker.io:
        endpoints:
          - http://$REGISTRY_CACHE
      ghcr.io:
        endpoints:
          - http://$REGISTRY_CACHE
    config:
      $REGISTRY_CACHE:
        tls:
          insecureSkipVerify: true
  features:
    rbac: true
    stableHostname: true
    apidCheckExtKeyUsage: true
    diskQuotaSupport: true
    kubernetesTalosAPIAccess:
      enabled: true
      allowedRoles:
        - os:admin
      allowedKubernetesNamespaces:
        - kube-system
  sysctls:
    net.bridge.bridge-nf-call-iptables: "1"
    net.bridge.bridge-nf-call-ip6tables: "1"
    net.ipv4.ip_forward: "1"
    net.ipv6.conf.all.forwarding: "1"
  disks:
    - device: /dev/xvdb
      partitions:
        - mountpoint: /var/lib/longhorn
cluster:
  id: $(uuidgen)
  secret: $(openssl rand -base64 32)
  controlPlane:
    endpoint: https://[$IPV6_ADDRESS]:6443
  clusterName: talos-direct-cluster
  network:
    dnsDomain: cluster.local
    podSubnets:
      - 10.244.0.0/16
      - fd40:10:244::/56
    serviceSubnets:
      - 10.96.0.0/12
      - fd40:10:96::/112
  proxy:
    disabled: false
  apiServer:
    image: registry.k8s.io/kube-apiserver:v1.31.3
    certSANs:
      - $IPV6_ADDRESS
      - 10.10.1.108
    auditPolicy:
      rules:
        - level: Metadata
  controllerManager:
    image: registry.k8s.io/kube-controller-manager:v1.31.3
  scheduler:
    image: registry.k8s.io/kube-scheduler:v1.31.3
  discovery:
    enabled: true
    registries:
      kubernetes:
        disabled: false
      service:
        disabled: false
  etcd:
    image: gcr.io/etcd-development/etcd:v3.5.16
    ca:
      crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...  # Generate real cert
      key: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVkt...  # Generate real key
  coreDNS:
    disabled: false
    image: registry.k8s.io/coredns/coredns:v1.11.3
  extraManifests:
    - https://raw.githubusercontent.com/alex-shpak/longhorn/main/deploy/longhorn.yaml
EOF

echo "🎯 Generated Talos config for node"
echo "⚠️  Note: You'll need to generate real certificates and apply this config with:"
echo "   talosctl config endpoint $IPV6_ADDRESS"
echo "   talosctl apply-config --insecure --nodes $IPV6_ADDRESS --file talos-config/controlplane.yaml"
echo ""
echo "🔍 Monitor boot: aws ec2 get-console-output --region eu-west-1 --instance-id $INSTANCE_ID"
echo "🌐 Node IPv6: $IPV6_ADDRESS"
echo "💾 Storage disk: /dev/xvdb (100GB) will be mounted at /var/lib/longhorn"

# Check if instance is accessible
echo "⏳ Waiting 60s for Talos API to be ready..."
sleep 60

echo "🧪 Testing Talos API connectivity..."
curl -k https://[$IPV6_ADDRESS]:50000/healthz || echo "❌ Talos API not ready yet"

echo ""
echo "📋 Next steps:"
echo "1. Install talosctl: curl -sL https://talos.dev/install | sh"
echo "2. Generate real certificates: talosctl gen config talos-cluster https://[$IPV6_ADDRESS]:6443"
echo "3. Apply config: talosctl apply-config --insecure --nodes $IPV6_ADDRESS --file controlplane.yaml"
echo "4. Bootstrap cluster: talosctl bootstrap --nodes $IPV6_ADDRESS"
echo "5. Get kubeconfig: talosctl kubeconfig --nodes $IPV6_ADDRESS"