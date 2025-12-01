#!/usr/bin/env bash
# simple-talos-launch.sh - Generate config with known IP, launch once
set -euo pipefail

REGION="eu-west-1"
SECURITY_GROUP="sg-0e6b4a78092854897"
SUBNET_ID="subnet-07a140ab2b20bf89b"
TALOS_AMI="ami-07898be81f2028262"

# Configuration - we know these addresses ahead of time
IPV4_ADDRESS="10.10.1.119"
CLUSTER_ENDPOINT="https://${IPV4_ADDRESS}:6443"

echo "🚀 Generating Talos config with known endpoint: $CLUSTER_ENDPOINT"

# Clean up and generate config once with correct endpoint
rm -f controlplane.yaml worker.yaml talosconfig

talosctl gen config talos-cozystack-cluster $CLUSTER_ENDPOINT \
    --with-examples=false \
    --with-docs=false \
    --with-kubespan \
    --install-disk /dev/xvda \
    --config-patch '@time-server-patch.yaml'

echo "📝 Launching instance with correct config..."

INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id $TALOS_AMI \
  --instance-type c7g.large \
  --security-group-ids $SECURITY_GROUP \
  --subnet-id $SUBNET_ID \
  --private-ip-address $IPV4_ADDRESS \
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
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=talos-simple}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ Created instance: $INSTANCE_ID at $IPV4_ADDRESS"

echo ""
echo "📋 Copy files to bastion and bootstrap:"
echo "   scp talosconfig controlplane.yaml worker.yaml user@bastion:~/"
echo ""
echo "🤖 On bastion (wait ~3 min for Talos API):"
echo "   export TALOSCONFIG=\$(pwd)/talosconfig"
echo "   talosctl config endpoint $IPV4_ADDRESS"
echo "   talosctl config nodes $IPV4_ADDRESS"
echo ""
echo "   # Test connection"
echo "   talosctl health --server=false"
echo ""
echo "   # Bootstrap cluster"
echo "   talosctl bootstrap"
echo "   talosctl health"
echo ""
echo "   # Get kubeconfig and test"
echo "   talosctl kubeconfig ."
echo "   export KUBECONFIG=\$(pwd)/kubeconfig"
echo "   kubectl get nodes"
echo ""
echo "🌐 Instance: $INSTANCE_ID"
echo "📍 Endpoint: $CLUSTER_ENDPOINT"