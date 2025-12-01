#!/usr/bin/env bash
# launch-and-configure-talos.sh - Launch node first, then generate config with correct IP
set -euo pipefail

REGION="eu-west-1"
SECURITY_GROUP="sg-0e6b4a78092854897"
SUBNET_ID="subnet-07a140ab2b20bf89b"
TALOS_AMI="ami-07898be81f2028262"

echo "🚀 Step 1: Launching Talos instance first..."

INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id $TALOS_AMI \
  --instance-type c7g.large \
  --security-group-ids $SECURITY_GROUP \
  --subnet-id $SUBNET_ID \
  --private-ip-address 10.10.1.115 \
  --ipv6-address-count 1 \
  --block-device-mappings '[
    {
      "DeviceName": "/dev/xvda",
      "Ebs": {
        "VolumeSize": 20,
        "VolumeType": "gp3",
        "DeleteOnTermination": true
      }
    }
  ]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=talos-correct-order}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ Created instance: $INSTANCE_ID"

echo "⏳ Step 2: Waiting for instance to start..."
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID

echo "🌐 Step 3: Getting IPv6 address..."
IPV6_ADDRESS=$(aws ec2 describe-instances \
  --region $REGION \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Ipv6Addresses[0].Ipv6Address' \
  --output text)

echo "📍 Instance IPv6: $IPV6_ADDRESS"

echo "📝 Step 4: Generating config with correct endpoint..."
CLUSTER_ENDPOINT="https://[$IPV6_ADDRESS]:6443"
echo "🎯 Cluster endpoint: $CLUSTER_ENDPOINT"

# Clean up any old configs
rm -f controlplane.yaml worker.yaml talosconfig

# Generate config with real endpoint
talosctl gen config talos-cozystack-cluster $CLUSTER_ENDPOINT \
    --with-examples=false \
    --with-docs=false \
    --with-kubespan \
    --install-disk /dev/xvda \
    --config-patch '@time-server-patch.yaml'

echo "🏗️ Step 5: Applying config to running instance..."
# Convert config to base64 and apply it
CONTROLPLANE_B64=$(base64 < controlplane.yaml)

# Apply the config via user data update (this won't work on running instance)
# Instead, we need to apply it via talosctl apply-config

echo "⏳ Waiting for Talos API to be ready..."
export TALOSCONFIG=$(pwd)/talosconfig
talosctl config endpoint 10.10.1.115
talosctl config nodes 10.10.1.115

# Wait for API to be ready
for i in {1..20}; do
    if talosctl health --server=false 2>/dev/null; then
        echo "✅ Talos API ready!"
        break
    fi
    echo "🔍 Attempt $i/20: Waiting for Talos API..."
    sleep 10
done

echo "📋 Step 6: Applying machine config..."
talosctl apply-config --nodes 10.10.1.115 --file controlplane.yaml

echo "⏳ Waiting for config to be applied..."
sleep 30

echo "🚀 Step 7: Bootstrapping cluster..."
talosctl bootstrap

echo "✅ Cluster ready!"
echo ""
echo "📋 Copy these files to bastion:"
echo "   - talosconfig"
echo "   - controlplane.yaml" 
echo "   - worker.yaml"
echo ""
echo "💫 Then on bastion run:"
echo "   export TALOSCONFIG=\$(pwd)/talosconfig"
echo "   talosctl config endpoint 10.10.1.115"
echo "   talosctl config nodes 10.10.1.115"
echo "   talosctl health"
echo "   talosctl kubeconfig ."
echo "   export KUBECONFIG=\$(pwd)/kubeconfig"
echo "   kubectl get nodes"