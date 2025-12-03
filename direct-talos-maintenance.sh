#!/bin/bash

# direct-talos-maintenance.sh - Deploy official Talos AMI in maintenance mode
set -e

echo "🎯 Launching official Talos ARM64 AMI in maintenance mode..."

# Find latest official Talos ARM64 AMI
echo "🔍 Finding official Talos v1.11.5 ARM64 AMI..."
TALOS_AMI=$(aws ec2 describe-images \
    --region eu-west-1 \
    --owners 540036508848 \
    --filters "Name=name,Values=talos-v1.11.5-arm64" \
              "Name=state,Values=available" \
    --query 'Images[0].ImageId' \
    --output text)

echo "📀 Using official Talos ARM64 AMI: $TALOS_AMI"

# Fixed IP for consistency  
IPV4_ADDRESS="10.10.1.106"

# Create minimal cloud-init for maintenance mode (no config = maintenance mode)
cat > cloud-init.yaml << EOF
#cloud-config
# No Talos config = maintenance mode by default
runcmd:
  - echo "Talos should boot into maintenance mode"
EOF

echo "📝 Created minimal cloud-init for maintenance mode"

# Launch instance with official Talos AMI
echo "🚀 Launching Talos instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --region eu-west-1 \
    --image-id $TALOS_AMI \
    --count 1 \
    --instance-type t4g.small \
    --security-group-ids sg-0e6b4a78092854897 \
    --subnet-id subnet-07a140ab2b20bf89b \
    --private-ip-address $IPV4_ADDRESS \
    --ipv6-address-count 1 \
    --no-associate-public-ip-address \
    --user-data file://cloud-init.yaml \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=talos-maintenance-mode}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "✅ Created instance: $INSTANCE_ID at $IPV4_ADDRESS"

# Wait for instance to be running
echo "⏳ Waiting for instance to be running..."
aws ec2 wait instance-running --region eu-west-1 --instance-ids $INSTANCE_ID

echo "🎯 Talos should be booting into maintenance mode..."
echo "⌛ Wait ~3-5 minutes for Talos API to be available"
echo ""
echo "🔍 Test connectivity:"
echo "   talosctl -n $IPV4_ADDRESS -e $IPV4_ADDRESS health --server=false"
echo ""
echo "🌐 Then run Talm discovery:"
echo "   talm -n $IPV4_ADDRESS -e $IPV4_ADDRESS template -t templates/controlplane.yaml -i > nodes/node1.yaml"
echo ""
echo "💻 Instance: $INSTANCE_ID"
echo "📍 IP: $IPV4_ADDRESS"

rm -f cloud-init.yaml