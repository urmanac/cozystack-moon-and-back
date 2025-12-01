#!/usr/bin/env bash
# simple-launch-talos.sh - Launch instance with minimal config, then configure properly
set -euo pipefail

REGION="eu-west-1"
SECURITY_GROUP="sg-0e6b4a78092854897"
SUBNET_ID="subnet-07a140ab2b20bf89b" 
TALOS_AMI="ami-07898be81f2028262"

echo "🚀 Step 1: Launching basic Talos instance..."

# Launch with minimal/empty user data first
echo "#cloud-config" > minimal-userdata.yaml

INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id $TALOS_AMI \
  --instance-type c7g.large \
  --security-group-ids $SECURITY_GROUP \
  --subnet-id $SUBNET_ID \
  --private-ip-address 10.10.1.115 \
  --ipv6-address-count 1 \
  --user-data file://minimal-userdata.yaml \
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
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=talos-step-by-step}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ Created instance: $INSTANCE_ID"

echo "⏳ Step 2: Waiting for instance to start..."
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID

echo "🌐 Step 3: Getting actual IP addresses..."
IPV6_ADDRESS=$(aws ec2 describe-instances \
  --region $REGION \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Ipv6Addresses[0].Ipv6Address' \
  --output text)

echo "📍 Instance IPs: 10.10.1.115 (IPv4), $IPV6_ADDRESS (IPv6)"

echo "📝 Step 4: Generating config with correct endpoint..."
CLUSTER_ENDPOINT="https://[$IPV6_ADDRESS]:6443"
echo "🎯 Cluster endpoint: $CLUSTER_ENDPOINT"

# Clean up old configs
rm -f controlplane.yaml worker.yaml talosconfig minimal-userdata.yaml

# Generate config with real endpoint
talosctl gen config talos-cozystack-cluster $CLUSTER_ENDPOINT \
    --with-examples=false \
    --with-docs=false \
    --with-kubespan \
    --install-disk /dev/xvda \
    --config-patch '@time-server-patch.yaml'

echo ""
echo "✅ Configuration generated with correct endpoint!"
echo ""
echo "📋 Next steps:"
echo "1. Copy these files to bastion:"
echo "   scp talosconfig controlplane.yaml worker.yaml user@bastion:~/"
echo ""  
echo "2. On bastion, wait for Talos API (~2 min) then run:"
echo "   export TALOSCONFIG=\$(pwd)/talosconfig"
echo "   talosctl config endpoint 10.10.1.115"
echo "   talosctl config nodes 10.10.1.115"
echo "   talosctl health --server=false  # Test connection"
echo "   talosctl apply-config --nodes 10.10.1.115 --file controlplane.yaml  # Apply config"
echo "   sleep 30  # Wait for config to apply"
echo "   talosctl bootstrap  # Start cluster"
echo "   talosctl health  # Check cluster health"
echo "   talosctl kubeconfig .  # Get kubeconfig"
echo "   export KUBECONFIG=\$(pwd)/kubeconfig"
echo "   kubectl get nodes  # Test Kubernetes"
echo ""
echo "🌐 Instance: $INSTANCE_ID"
echo "📍 IPv4: 10.10.1.115"
echo "📍 IPv6: $IPV6_ADDRESS"