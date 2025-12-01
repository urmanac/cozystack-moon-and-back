#!/usr/bin/env bash
# deploy-talos-from-bastion.sh - Complete Talos deployment from ARM64 bastion host
set -euo pipefail

# Configuration
REGION="eu-west-1"
VPC_ID="vpc-04af837e642c001c6"
SECURITY_GROUP="sg-0e6b4a78092854897"
SUBNET_ID="subnet-07a140ab2b20bf89b"
TALOS_AMI="ami-07898be81f2028262"
CUSTOM_TALOS_IMAGE="ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/talos:latest"

# Instance configuration
INSTANCE_TYPE="c7g.large"
INSTANCE_IP="10.10.1.111"
INSTANCE_NAME="talos-bastion-deploy"

echo "🚀 Deploying Talos ARM64 cluster from bastion host"
echo "📍 Region: $REGION, VPC: $VPC_ID"
echo "🐧 Custom Image: $CUSTOM_TALOS_IMAGE"

# Install dependencies if not present
if ! command -v talosctl &> /dev/null; then
    echo "📥 Installing talosctl for linux-arm64..."
    curl -sL https://github.com/siderolabs/talos/releases/download/v1.11.5/talosctl-linux-arm64 -o talosctl
    chmod +x talosctl
    sudo mv talosctl /usr/local/bin/
fi

if ! command -v jq &> /dev/null; then
    echo "📥 Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq
fi

# Clean up any existing configs
rm -f controlplane.yaml worker.yaml talosconfig time-server-patch.yaml

echo "📝 Creating Talos configuration patch..."
cat > time-server-patch.yaml << 'EOF'
machine:
  time:
    servers:
      - 169.254.169.123
  registries:
    mirrors:
      docker.io:
        endpoints:
          - http://10.10.1.100:5050
          - http://10.10.1.100:5051
          - http://10.10.1.100:5052
          - http://10.10.1.100:5053
          - http://10.10.1.100:5054
      ghcr.io:
        endpoints:
          - http://10.10.1.100:5050
          - http://10.10.1.100:5051
          - http://10.10.1.100:5052
          - http://10.10.1.100:5053
          - http://10.10.1.100:5054
    config:
      10.10.1.100:5050:
        tls:
          insecureSkipVerify: true
      10.10.1.100:5051:
        tls:
          insecureSkipVerify: true
      10.10.1.100:5052:
        tls:
          insecureSkipVerify: true
      10.10.1.100:5053:
        tls:
          insecureSkipVerify: true
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
EOF

echo "🔑 Generating Talos configuration..."
# We'll use a placeholder endpoint and update it after launch
CLUSTER_ENDPOINT="https://[::1]:6443"
talosctl gen config talos-cozystack-cluster $CLUSTER_ENDPOINT \
    --with-examples=false \
    --with-docs=false \
    --with-kubespan \
    --install-disk /dev/xvda \
    --config-patch '@time-server-patch.yaml'

echo "🏗️ Launching Talos instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id $TALOS_AMI \
  --instance-type $INSTANCE_TYPE \
  --security-group-ids $SECURITY_GROUP \
  --subnet-id $SUBNET_ID \
  --private-ip-address $INSTANCE_IP \
  --ipv6-address-count 1 \
  --user-data file://controlplane.yaml \
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
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
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

# Update the cluster configuration with the real endpoint
REAL_CLUSTER_ENDPOINT="https://[$IPV6_ADDRESS]:6443"
echo "🔧 Updating cluster endpoint to: $REAL_CLUSTER_ENDPOINT"

# Regenerate config with real endpoint
talosctl gen config talos-cozystack-cluster $REAL_CLUSTER_ENDPOINT \
    --with-examples=false \
    --with-docs=false \
    --with-kubespan \
    --install-disk /dev/xvda \
    --config-patch '@time-server-patch.yaml' \
    --force

# Configure talosctl
export TALOSCONFIG=$(pwd)/talosconfig
talosctl config endpoint $IPV6_ADDRESS
talosctl config nodes $IPV6_ADDRESS

echo "⏳ Waiting for Talos API to be ready (this may take 2-3 minutes)..."
for i in {1..30}; do
    if talosctl health --server=false 2>/dev/null; then
        echo "✅ Talos API is ready!"
        break
    fi
    echo "🔍 Attempt $i/30: Talos API not ready yet, waiting 10s..."
    sleep 10
done

# Check if we can connect
if ! talosctl health --server=false 2>/dev/null; then
    echo "❌ Failed to connect to Talos API"
    echo "🔍 Check console output: aws ec2 get-console-output --region $REGION --instance-id $INSTANCE_ID"
    exit 1
fi

echo "🚀 Bootstrapping etcd..."
talosctl bootstrap

echo "⏳ Waiting for cluster to be healthy..."
for i in {1..20}; do
    if talosctl health 2>/dev/null; then
        echo "✅ Cluster is healthy!"
        break
    fi
    echo "🔍 Attempt $i/20: Cluster not healthy yet, waiting 15s..."
    sleep 15
done

echo "📋 Retrieving kubeconfig..."
talosctl kubeconfig .
export KUBECONFIG=$(pwd)/kubeconfig

echo ""
echo "🎉 Talos cluster deployed successfully!"
echo "📊 Test the cluster:"
echo "   export KUBECONFIG=$(pwd)/kubeconfig"
echo "   kubectl get nodes"
echo "   talosctl health"
echo ""
echo "📁 Configuration files created:"
echo "   - talosconfig (Talos API access)"
echo "   - kubeconfig (Kubernetes access)"
echo "   - controlplane.yaml (machine config)"
echo ""
echo "🌐 Cluster endpoint: $REAL_CLUSTER_ENDPOINT"
echo "🌍 Node IPv6: $IPV6_ADDRESS"
echo "💾 Instance ID: $INSTANCE_ID"
echo ""
echo "🔍 Monitor: aws ec2 get-console-output --region $REGION --instance-id $INSTANCE_ID"

# Test basic functionality
echo "🧪 Testing cluster..."
kubectl get nodes || echo "❌ Kubernetes not ready yet"
talosctl version || echo "❌ Talos connection issue"

echo "✨ Deployment complete!"