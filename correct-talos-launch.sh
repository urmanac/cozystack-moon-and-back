#!/usr/bin/env bash
# correct-talos-launch.sh - Launch with real IP, don't regenerate keys
set -euo pipefail

REGION="eu-west-1"
SECURITY_GROUP="sg-0e6b4a78092854897"
SUBNET_ID="subnet-07a140ab2b20bf89b"
TALOS_AMI="ami-07898be81f2028262"

echo "🚀 Step 1: Launching instance to get real IP first..."

# Launch instance without user data to get the IP
INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id $TALOS_AMI \
  --instance-type c7g.large \
  --security-group-ids $SECURITY_GROUP \
  --subnet-id $SUBNET_ID \
  --private-ip-address 10.10.1.118 \
  --ipv6-address-count 1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=talos-pki-preserved}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ Created instance: $INSTANCE_ID"

echo "⏳ Step 2: Waiting for instance to get IP..."
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID

echo "🌐 Step 3: Getting real IPv6 address..."
IPV6_ADDRESS=$(aws ec2 describe-instances \
  --region $REGION \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Ipv6Addresses[0].Ipv6Address' \
  --output text)

echo "📍 Instance IPs: 10.10.1.118 (IPv4), $IPV6_ADDRESS (IPv6)"

echo "🔧 Step 4: Generating config with IPv4 endpoint (one time only)..."
IPV4_ENDPOINT="https://10.10.1.117:6443"
echo "🎯 Cluster endpoint: $IPV4_ENDPOINT"

# Clean up and generate config with IPv4 endpoint ONCE
rm -f controlplane.yaml worker.yaml talosconfig

talosctl gen config talos-cozystack-cluster $IPV4_ENDPOINT \
    --with-examples=false \
    --with-docs=false \
    --with-kubespan \
    --install-disk /dev/xvda \
    --config-patch '@time-server-patch.yaml'

echo "📝 Step 5: Stopping instance to apply user data..."
aws ec2 stop-instances --region $REGION --instance-ids $INSTANCE_ID
aws ec2 wait instance-stopped --region $REGION --instance-ids $INSTANCE_ID

echo "🔧 Step 6: Updating instance with proper config..."
# Convert config to base64 for attribute update
CONTROLPLANE_B64=$(base64 < controlplane.yaml)

# Update user data attribute
aws ec2 modify-instance-attribute \
  --region $REGION \
  --instance-id $INSTANCE_ID \
  --user-data Value="$CONTROLPLANE_B64"

echo "🚀 Step 7: Starting instance with correct config..."
aws ec2 start-instances --region $REGION --instance-ids $INSTANCE_ID
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID

echo ""
echo "✅ Instance launched with consistent PKI and IPv4 endpoint!"
echo ""
echo "📋 Copy to bastion and bootstrap:"
echo "   scp talosconfig controlplane.yaml worker.yaml user@bastion:~/"
echo ""
echo "🤖 On bastion (wait ~3 min for Talos API):"
echo "   export TALOSCONFIG=\$(pwd)/talosconfig"
echo "   talosctl config endpoint 10.10.1.117"
echo "   talosctl config nodes 10.10.1.117"
echo ""
echo "   # Test connection (should work now)"
echo "   talosctl health --server=false"
echo ""
echo "   # Bootstrap directly (no apply-config needed)"
echo "   talosctl bootstrap"
echo "   talosctl health"
echo ""
echo "   # Get kubeconfig"
echo "   talosctl kubeconfig ."
echo "   export KUBECONFIG=\$(pwd)/kubeconfig"
echo "   kubectl get nodes"
echo ""
echo "🌐 Instance: $INSTANCE_ID"
echo "📍 IPv4: 10.10.1.117, IPv6: $IPV6_ADDRESS"