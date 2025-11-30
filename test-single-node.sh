#!/usr/bin/env bash
# test-single-node.sh - Launch single ARM64 node for debugging
set -eo pipefail

# Configuration
REGION="eu-west-1"
VPC_ID="vpc-04af837e642c001c6"
SECURITY_GROUP="sg-0e6b4a78092854897"
REGISTRY_CACHE="10.10.1.100:5054"
CUSTOM_TALOS_IMAGE="ghcr.io/urmanac/cozystack-assets/talos:demo-stable"

echo "🚀 Testing single ARM64 Talos node in eu-west-1..."
echo "📍 VPC: $VPC_ID"
echo "🔒 Security Group: $SECURITY_GROUP"
echo "📦 Registry Cache: $REGISTRY_CACHE"
echo "🐧 Custom Talos: $CUSTOM_TALOS_IMAGE"

# Get latest Ubuntu 22.04 ARM64 AMI
echo "🔍 Finding latest Ubuntu 22.04 ARM64 AMI..."
AMI_ID=$(aws ec2 describe-images \
  --region $REGION \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*" \
            "Name=state,Values=available" \
  --query 'Images|sort_by(@,&CreationDate)[-1].ImageId' \
  --output text)

echo "📀 Using AMI: $AMI_ID"

# Generate simplified boot-to-Talos user data
echo "📝 Generating boot-to-Talos user data..."
cat > test-userdata.yaml << EOF
#cloud-config
write_files:
- path: /opt/boot-to-talos.sh
  permissions: '0755'
  content: |
    #!/bin/bash
    set -euo pipefail
    echo "🚀 Starting boot-to-Talos transition..." | tee -a /var/log/boot-to-talos.log
    
    # Install Docker for image operations
    apt-get update | tee -a /var/log/boot-to-talos.log
    apt-get install -y docker.io | tee -a /var/log/boot-to-talos.log
    systemctl start docker | tee -a /var/log/boot-to-talos.log
    
    # Configure Docker to use registry caches
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'DOCKER_EOF'
{
  "registry-mirrors": ["http://${REGISTRY_CACHE}"],
  "insecure-registries": ["${REGISTRY_CACHE}"]
}
DOCKER_EOF
    systemctl restart docker | tee -a /var/log/boot-to-talos.log
    
    # Test registry connectivity
    echo "📦 Testing registry cache connectivity..." | tee -a /var/log/boot-to-talos.log
    curl -v http://${REGISTRY_CACHE}/v2/ 2>&1 | tee -a /var/log/boot-to-talos.log || true
    
    # Pull custom Talos image via registry cache
    echo "🔍 Pulling: ${CUSTOM_TALOS_IMAGE}" | tee -a /var/log/boot-to-talos.log
    docker pull "${CUSTOM_TALOS_IMAGE}" 2>&1 | tee -a /var/log/boot-to-talos.log || true
    
    # List what we got
    docker images | tee -a /var/log/boot-to-talos.log
    
    echo "Boot-to-Talos test complete" | tee -a /var/log/boot-to-talos.log

runcmd:
- /opt/boot-to-talos.sh
final_message: "Ubuntu → Talos transition test initiated"
EOF

echo "🏗️ Creating test ARM64 node..."

INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id "$AMI_ID" \
  --instance-type c7g.large \
  --security-group-ids $SECURITY_GROUP \
  --subnet-id subnet-0ef9817bc457d9d76 \
  --private-ip-address 10.10.10.11 \
  --user-data file://test-userdata.yaml \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-control-01}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ Created test instance: $INSTANCE_ID"
echo "🔍 Monitor with: aws ec2 get-console-output --region eu-west-1 --instance-id $INSTANCE_ID"
echo "🧐 Check logs later: ssh ubuntu@10.10.10.10 'cat /var/log/boot-to-talos.log'"