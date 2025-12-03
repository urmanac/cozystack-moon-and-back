#!/bin/bash

# boot-to-talos-cozystack.sh - Deploy CozyStack image via kexec
set -e

echo "🥾 Launching ARM64 instance with boot-to-talos to CozyStack image..."

# Get latest Ubuntu 24.04 ARM64 AMI (should have good kexec support!)
echo "🔍 Finding latest Ubuntu 24.04 ARM64 AMI..."
UBUNTU_AMI=$(aws ec2 describe-images \
    --region eu-west-1 \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*" \
              "Name=state,Values=available" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text)

echo "📀 Using Ubuntu ARM64 AMI: $UBUNTU_AMI"

# Fixed IP for consistency
IPV4_ADDRESS="10.10.1.103"
COZYSTACK_IMAGE="10.10.1.100:5054/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/talos:latest"

# Create cloud-init that uses boot-to-talos to kexec into CozyStack
cat > cloud-init.yaml << EOF
#cloud-config
package_update: true
packages:
  - kexec-tools
  - curl
  - tar

# Add SSH key for debugging access
users:
  - name: ubuntu
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFAJEwbe8ZuresTTfBGXSmpFKDcAkd6584qaA3y/3uVQ yebyen@Kingdons-MacBook-Pro-2.local

runcmd:
  # Download boot-to-talos from IPv6 mirror (now with IPv6 configured)
  - curl -L http://[2620:8d:8000:e49:a00:27ff:fe2f:b6d9]/boot-to-talos-linux-arm64.tar.gz -o /tmp/boot-to-talos.tar.gz
  - cd /tmp && tar -xzf boot-to-talos.tar.gz
  - mv boot-to-talos /usr/local/bin/boot-to-talos
  - chmod +x /usr/local/bin/boot-to-talos
  
  # Boot into CozyStack Talos image via kexec (using registry cache)
  - sleep 30  # Give network time to stabilize
  - /usr/local/bin/boot-to-talos -image $COZYSTACK_IMAGE -yes

power_state:
  delay: "+1"
  mode: reboot
  message: Rebooting to complete boot-to-talos setup
  timeout: 30
  condition: True
EOF

echo "📝 Created cloud-init with boot-to-talos to CozyStack image"

# Launch instance with Amazon Linux 2023 
echo "🚀 Launching instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --region eu-west-1 \
    --image-id $UBUNTU_AMI \
    --count 1 \
    --instance-type t4g.small \
    --security-group-ids sg-0e6b4a78092854897 \
    --subnet-id subnet-07a140ab2b20bf89b \
    --private-ip-address $IPV4_ADDRESS \
    --ipv6-address-count 1 \
    --no-associate-public-ip-address \
    --user-data file://cloud-init.yaml \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cozystack-boot-to-talos}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "✅ Created instance: $INSTANCE_ID at $IPV4_ADDRESS"

# Wait for instance to be running
echo "⏳ Waiting for instance to be running..."
aws ec2 wait instance-running --region eu-west-1 --instance-ids $INSTANCE_ID

echo "🥾 Instance is running and executing boot-to-talos..."
echo "⌛ Wait ~5-10 minutes for:"
echo "   1. Ubuntu to boot and setup"
echo "   2. boot-to-talos to download CozyStack image"
echo "   3. kexec into Talos maintenance mode"
echo ""
echo "🔍 Then check serial console for Talos maintenance mode"
echo "💻 Instance: $INSTANCE_ID"
echo "📍 IP: $IPV4_ADDRESS"
echo "🌐 Once in maintenance mode, you can use Talm discovery!"

rm -f cloud-init.yaml