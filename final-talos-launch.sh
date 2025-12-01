#!/usr/bin/env bash
# final-talos-launch.sh - Launch with placeholder config, then update with real endpoint
set -euo pipefail

REGION="eu-west-1"
SECURITY_GROUP="sg-0e6b4a78092854897"
SUBNET_ID="subnet-07a140ab2b20bf89b"
TALOS_AMI="ami-07898be81f2028262"

echo "🚀 Step 1: Creating initial config with placeholder endpoint..."

# Generate initial config with placeholder endpoint
rm -f controlplane.yaml worker.yaml talosconfig
PLACEHOLDER_ENDPOINT="https://[::1]:6443"

talosctl gen config talos-cozystack-cluster $PLACEHOLDER_ENDPOINT \
    --with-examples=false \
    --with-docs=false \
    --with-kubespan \
    --install-disk /dev/xvda \
    --config-patch '@time-server-patch.yaml'

echo "📝 Step 2: Launching instance with initial config..."

INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id $TALOS_AMI \
  --instance-type c7g.large \
  --security-group-ids $SECURITY_GROUP \
  --subnet-id $SUBNET_ID \
  --private-ip-address 10.10.1.116 \
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
    }
  ]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=talos-final}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ Created instance: $INSTANCE_ID"

echo "⏳ Step 3: Waiting for instance to start..."
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID

echo "🌐 Step 4: Getting real IPv6 address..."
IPV6_ADDRESS=$(aws ec2 describe-instances \
  --region $REGION \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Ipv6Addresses[0].Ipv6Address' \
  --output text)

echo "📍 Instance IPs: 10.10.1.116 (IPv4), $IPV6_ADDRESS (IPv6)"

echo "🔧 Step 5: Generating final config with real endpoint..."
REAL_ENDPOINT="https://[$IPV6_ADDRESS]:6443"
echo "🎯 Real cluster endpoint: $REAL_ENDPOINT"

# Generate final configs with real endpoint
rm -f controlplane.yaml worker.yaml talosconfig

talosctl gen config talos-cozystack-cluster $REAL_ENDPOINT \
    --with-examples=false \
    --with-docs=false \
    --with-kubespan \
    --install-disk /dev/xvda \
    --config-patch '@time-server-patch.yaml'

echo ""
echo "✅ Final configuration ready!"
echo ""
echo "📋 Copy to bastion and run:"
echo "   scp talosconfig controlplane.yaml worker.yaml user@bastion:~/"
echo ""
echo "🤖 On bastion (wait ~2 min for Talos API first):"
echo "   export TALOSCONFIG=\$(pwd)/talosconfig"
echo "   talosctl config endpoint 10.10.1.116" 
echo "   talosctl config nodes 10.10.1.116"
echo ""
echo "   # Test basic connection first"
echo "   talosctl health --server=false"
echo ""
echo "   # Apply the config with real endpoint"  
echo "   talosctl apply-config --nodes 10.10.1.116 --file controlplane.yaml"
echo "   sleep 30"
echo ""
echo "   # Bootstrap the cluster"
echo "   talosctl bootstrap"
echo "   talosctl health"
echo ""
echo "   # Get kubeconfig and test"
echo "   talosctl kubeconfig ."
echo "   export KUBECONFIG=\$(pwd)/kubeconfig"
echo "   kubectl get nodes"
echo ""
echo "🌐 Instance: $INSTANCE_ID"
echo "📍 IPv4: 10.10.1.115, IPv6: $IPV6_ADDRESS"