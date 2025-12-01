#!/usr/bin/env bash
# talos-proper-deployment.sh - Deploy Talos following official AWS guide
set -eo pipefail

# Configuration
REGION="eu-west-1"
VPC_ID="vpc-04af837e642c001c6"
SECURITY_GROUP="sg-0e6b4a78092854897"
REGISTRY_CACHE="10.10.1.100:5054"
CUSTOM_TALOS_IMAGE="ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/talos:latest"

# Official Talos v1.11.5 ARM64 AMI (verified from official releases)
TALOS_AMI="ami-07898be81f2028262"

echo "🚀 Deploying Talos following official AWS guide..."
echo "📍 VPC: $VPC_ID"
echo "🔒 Security Group: $SECURITY_GROUP"
echo "📦 Registry Cache: $REGISTRY_CACHE"
echo "🐧 Custom Talos: $CUSTOM_TALOS_IMAGE"
echo "📀 Talos AMI: $TALOS_AMI"

# Check if talosctl is installed
if ! command -v talosctl &> /dev/null; then
    echo "📥 Installing talosctl..."
    curl -sL https://talos.dev/install | sh
    sudo mv talosctl /usr/local/bin/
fi

# Create AWS time server patch as per official guide
echo "📝 Creating AWS time server patch..."
cat > time-server-patch.yaml << 'EOF'
machine:
  time:
    servers:
      - 169.254.169.123
  registries:
    mirrors:
      docker.io:
        endpoints:
          - http://10.10.1.100:5054
      ghcr.io:
        endpoints:
          - http://10.10.1.100:5054
    config:
      10.10.1.100:5054:
        tls:
          insecureSkipVerify: true
  install:
    image: ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/talos:latest
  features:
    kubernetesTalosAPIAccess:
      enabled: true
      allowedRoles:
        - os:admin
      allowedKubernetesNamespaces:
        - kube-system
  disks:
    - device: /dev/xvdb
      partitions:
        - mountpoint: /var/lib/longhorn
EOF

# Generate Talos configuration with our custom patches
echo "🔑 Generating Talos configuration..."
# Use instance's future IPv6 address as endpoint
CLUSTER_ENDPOINT="https://[2a05:d018:106c:7801:295:6957:b303:1d7c]:6443"

talosctl gen config talos-cozystack-cluster $CLUSTER_ENDPOINT \
    --with-examples=false \
    --with-docs=false \
    --with-kubespan \
    --install-disk /dev/xvda \
    --config-patch '@time-server-patch.yaml'

echo "📋 Generated configuration files:"
ls -la *.yaml

echo "🏗️ Creating Talos node with proper configuration..."

# Base64 encode the controlplane config for user data
CONTROLPLANE_B64=$(base64 -w0 controlplane.yaml)

INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id "$TALOS_AMI" \
  --instance-type c7g.large \
  --security-group-ids $SECURITY_GROUP \
  --subnet-id subnet-07a140ab2b20bf89b \
  --private-ip-address 10.10.1.109 \
  --ipv6-address-count 1 \
  --user-data "data:text/plain;base64,$CONTROLPLANE_B64" \
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
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=talos-proper-01}]' \
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

# Export talosconfig for authentication
export TALOSCONFIG=$(pwd)/talosconfig

# Configure talosctl to talk to our node
echo "🔧 Configuring talosctl..."
talosctl config endpoint $IPV6_ADDRESS
talosctl config nodes $IPV6_ADDRESS

# Wait for Talos API to be ready
echo "⏳ Waiting for Talos API to be ready..."
for i in {1..20}; do
    if talosctl health --server=false 2>/dev/null; then
        echo "✅ Talos API is ready!"
        break
    fi
    echo "🔍 Attempt $i/20: Talos API not ready yet, waiting 30s..."
    sleep 30
done

# Bootstrap the cluster
echo "🚀 Bootstrapping etcd..."
talosctl bootstrap

# Wait for cluster to be healthy
echo "⏳ Waiting for cluster to be healthy..."
talosctl health

# Get kubeconfig
echo "📋 Retrieving kubeconfig..."
talosctl kubeconfig .
export KUBECONFIG=$(pwd)/kubeconfig

echo ""
echo "🎉 Talos cluster deployed successfully!"
echo "📊 Check cluster status:"
echo "   kubectl get nodes"
echo "   talosctl health"
echo "   talosctl dashboard"
echo ""
echo "🔍 Monitor console: aws ec2 get-console-output --region eu-west-1 --instance-id $INSTANCE_ID"
echo "🌐 Node IPv6: $IPV6_ADDRESS"
echo "💾 Storage disk: /dev/xvdb (100GB) mounted at /var/lib/longhorn"