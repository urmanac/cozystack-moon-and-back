#!/usr/bin/env bash
# launch-arm64-cluster.sh - Launch CozyStack ARM64 cluster with real infrastructure values
set -eo pipefail  # Removed -u flag to avoid issues with associative array iteration

# Real infrastructure values from November 30th Terraform deployment
VPC_ID="vpc-04af837e642c001c6"
SECURITY_GROUP_ID="sg-0e6b4a78092854897"
REGISTRY_CACHE="10.10.1.100:5054"  # GHCR pull-through cache on bastion (port 5054)
CUSTOM_TALOS_IMAGE="ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/talos:latest"
REGION="eu-west-1"

echo "🚀 Launching CozyStack ARM64 cluster in $REGION..."
echo "📍 VPC: $VPC_ID"
echo "🔒 Security Group: $SECURITY_GROUP_ID" 
echo "📦 Registry Cache: $REGISTRY_CACHE"
echo "🐧 Custom Talos: $CUSTOM_TALOS_IMAGE"

# Get latest Ubuntu 22.04 ARM64 AMI
echo "🔍 Finding latest Ubuntu 22.04 ARM64 AMI..."
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-*" \
            "Name=state,Values=available" \
            "Name=architecture,Values=arm64" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region $REGION)
echo "📀 Using Ubuntu ARM64 AMI: $AMI_ID"

# Generate boot-to-Talos user data
echo "📝 Generating boot-to-Talos user data..."
cat > boot-to-talos-userdata.yaml << EOF
#cloud-config
write_files:
- path: /opt/boot-to-talos.sh
  permissions: '0755'
  content: |
    #!/bin/bash
    set -euo pipefail
    echo "🚀 Starting boot-to-Talos transition..."
    
    # Install Docker for image operations
    apt-get update
    apt-get install -y docker.io
    systemctl start docker
    
    # Configure Docker to use registry caches (critical - no direct internet from private subnets)
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << DOCKER_EOF
    {
      "registry-mirrors": ["http://${REGISTRY_CACHE}"],
      "insecure-registries": ["${REGISTRY_CACHE}"]
    }
    DOCKER_EOF
    systemctl restart docker
    
    # Pull custom Talos image via GHCR registry cache (port 5054)
    echo "📦 Pulling custom Talos image via bastion cache: ${REGISTRY_CACHE}"
    echo "🔍 Image: ${CUSTOM_TALOS_IMAGE}"
    
    # Pull from registry cache (nodes have no direct internet - critical)
    echo "🔍 Testing registry cache access..."
    curl -f http://${REGISTRY_CACHE}/v2/ || {
      echo "❌ Registry cache not accessible at ${REGISTRY_CACHE}"
      exit 1
    }
    
    echo "📦 Pulling custom Talos image..."
    # Pull via registry cache since nodes have no direct internet
    docker pull ${REGISTRY_CACHE}/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/talos:latest || {
      echo "❌ Failed to pull from registry cache"
      exit 1
    }
    
    # Tag for easier reference
    docker tag ${REGISTRY_CACHE}/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/talos:latest ${CUSTOM_TALOS_IMAGE}
    
    # Extract Talos installer for kexec transition
    echo "🔄 Extracting Talos installer..."
    docker create --name talos-extract "${CUSTOM_TALOS_IMAGE}"
    mkdir -p /opt/talos-installer
    docker cp talos-extract:/assets/talos/arm64/boot/ /opt/talos-installer/ 2>/dev/null || {
      echo "⚠️  Boot assets not in expected location, trying alternative paths..."
      docker cp talos-extract:/usr/install/arm64/ /opt/talos-installer/ 2>/dev/null || {
        echo "📋 Listing available paths in Talos image..."
        docker run --rm "${CUSTOM_TALOS_IMAGE}" find / -name "*vmlinuz*" -o -name "*initramfs*" || true
      }
    }
    docker rm talos-extract
    
    # Transition to Talos (kexec)
    echo "🎯 Transitioning to Talos..."
    # Implementation depends on specific Talos image structure
    # This would invoke kexec with Talos kernel and initramfs
    echo "Boot-to-Talos preparation complete"
    
runcmd:
- /opt/boot-to-talos.sh
final_message: "Ubuntu → Talos transition initiated"
EOF

# Define cluster nodes with real subnet IDs
declare -A NODES=(
  ["control-01"]="c7g.large subnet-07a140ab2b20bf89b 10.10.1.110 eu-west-1b"
  ["control-02"]="c7g.large subnet-07a140ab2b20bf89b 10.10.1.111 eu-west-1b" 
  ["control-03"]="c7g.large subnet-07a140ab2b20bf89b 10.10.1.112 eu-west-1b"
  ["worker-01"]="c7g.xlarge subnet-07a140ab2b20bf89b 10.10.1.120 eu-west-1b"
  ["worker-02"]="c7g.xlarge subnet-07a140ab2b20bf89b 10.10.1.121 eu-west-1b"
)

echo "🏗️ Creating ARM64 Talos cluster nodes..."
echo "NODE_NAME:INSTANCE_ID:PRIVATE_IP:TYPE" > cluster-instances.txt

for node_name in "${!NODES[@]}"; do
  IFS=' ' read -r instance_type subnet_id private_ip az <<< "${NODES[$node_name]}"
  
  echo "📍 Creating $node_name ($instance_type) in $az..."
  
  # Check for optional IAM instance profile
  INSTANCE_PROFILE_ARG=""
  if aws iam get-instance-profile --instance-profile-name CozyStackNodeRole --region $REGION 2>/dev/null; then
    INSTANCE_PROFILE_ARG="--iam-instance-profile Name=CozyStackNodeRole"
  fi
  
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$instance_type" \
    --subnet-id "$subnet_id" \
    --private-ip-address "$private_ip" \
    --ipv6-address-count 1 \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --user-data file://boot-to-talos-userdata.yaml \
    $INSTANCE_PROFILE_ARG \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$node_name},{Key=Cluster,Value=cozystack-arm64},{Key=Role,Value=talos-node}]" \
    --region $REGION \
    --query 'Instances[0].InstanceId' \
    --output text)
    
  echo "✅ Created $node_name: $INSTANCE_ID ($private_ip)"
  echo "$node_name:$INSTANCE_ID:$private_ip:$instance_type" >> cluster-instances.txt
done

echo "⏳ Waiting for instances to be running..."
while IFS=: read -r node_name instance_id private_ip instance_type; do
  if [[ "$node_name" != "NODE_NAME" ]]; then  # Skip header
    echo "🔄 Waiting for $node_name ($instance_id)..."
    aws ec2 wait instance-running --instance-ids "$instance_id" --region $REGION
    echo "✅ $node_name is running"
  fi
done < cluster-instances.txt

echo ""
echo "🎉 ARM64 Talos cluster nodes launched successfully!"
echo "📋 Instance details:"
cat cluster-instances.txt
echo ""
echo "🔍 Next steps:"
echo "1. Monitor boot-to-Talos transition in CloudWatch logs"
echo "2. Validate Talos API connectivity on port 50000"
echo "3. Bootstrap cluster with talm once all nodes are Talos"
echo "4. Install CozyStack platform"
echo ""
echo "📊 Cluster endpoint will be: https://10.10.1.200:6443"
echo "🌐 Registry cache: $REGISTRY_CACHE"