#!/bin/bash
set -euo pipefail

# Force Talos into TRUE maintenance mode for Talm discovery
# This script tests multiple approaches to achieve maintenance mode

REGION="eu-west-1"
SUBNET_ID="subnet-07a140ab2b20bf89b"
VPC_ID="vpc-04af837e642c001c6"
AMI_ID="ami-0d0b5ac770722d15e"  # Official Talos v1.11.1 ARM64
INSTANCE_TYPE="t4g.small"
KEY_NAME="yebyen-key-pair"

echo "=== Testing Multiple Approaches to Force Talos Maintenance Mode ==="

# Find or create security group for Talos
echo "Finding security group for Talos..."
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=talos-*" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "None")

if [ "$SECURITY_GROUP_ID" = "None" ] || [ "$SECURITY_GROUP_ID" = "null" ]; then
    echo "Creating new security group for Talos..."
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --region "$REGION" \
        --group-name "talos-maintenance-sg" \
        --description "Security group for Talos maintenance mode testing" \
        --vpc-id "$VPC_ID" \
        --query 'GroupId' \
        --output text)
    
    # Add required rules for Talos
    # Allow Talos API (50000) from VPC (for bastion access)
    # NOTE: Originally used CIDR 10.10.0.0/16 but needed security group reference for bastion
    # Fixed with: aws ec2 authorize-security-group-ingress --group-id sg-083a002a99bb912ac --protocol tcp --port 50000 --source-group sg-0f9cb1bf403ae7dd1
    aws ec2 authorize-security-group-ingress \
        --region "$REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 50000 \
        --cidr 10.10.0.0/16
    
    # Allow Kubernetes API (6443) from VPC (for bastion access)
    aws ec2 authorize-security-group-ingress \
        --region "$REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 6443 \
        --cidr 10.10.0.0/16
    
    # Allow inter-node communication on all ports (for cluster formation)
    aws ec2 authorize-security-group-ingress \
        --region "$REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol all \
        --source-group "$SECURITY_GROUP_ID"
    
    # Allow SSH from VPC
    aws ec2 authorize-security-group-ingress \
        --region "$REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 10.10.0.0/16
fi

echo "Using security group: $SECURITY_GROUP_ID"

# Approach 1: Launch with absolutely NO user-data
echo ""
echo "Approach 1: Launching with NO user-data (should force maintenance mode)"

INSTANCE_ID_1=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --subnet-id "$SUBNET_ID" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --block-device-mappings '[{
        "DeviceName": "/dev/xvda",
        "Ebs": {
            "VolumeSize": 20,
            "VolumeType": "gp3",
            "DeleteOnTermination": true
        }
    }]' \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=talos-no-userdata-maintenance}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance 1 (no user-data): $INSTANCE_ID_1"

# Approach 2: Launch with explicitly empty user-data
echo ""
echo "Approach 2: Launching with empty user-data file"

# Create empty user-data file
echo "" > empty-user-data.txt

INSTANCE_ID_2=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --subnet-id "$SUBNET_ID" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --user-data file://empty-user-data.txt \
    --block-device-mappings '[{
        "DeviceName": "/dev/xvda",
        "Ebs": {
            "VolumeSize": 20,
            "VolumeType": "gp3",
            "DeleteOnTermination": true
        }
    }]' \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=talos-empty-userdata-maintenance}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance 2 (empty user-data): $INSTANCE_ID_2"

# Approach 3: Launch with invalid YAML to force failure
echo ""
echo "Approach 3: Launching with invalid YAML to force maintenance mode fallback"

cat > invalid-user-data.yaml << 'EOF'
# Invalid YAML that should force Talos to maintenance mode
invalid_key: [
  - incomplete yaml structure
  missing: closing bracket
EOF

INSTANCE_ID_3=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --subnet-id "$SUBNET_ID" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --user-data file://invalid-user-data.yaml \
    --block-device-mappings '[{
        "DeviceName": "/dev/xvda",
        "Ebs": {
            "VolumeSize": 20,
            "VolumeType": "gp3",
            "DeleteOnTermination": true
        }
    }]' \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=talos-invalid-yaml-maintenance}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance 3 (invalid YAML): $INSTANCE_ID_3"

# Wait for all instances to be running
echo ""
echo "Waiting for all instances to be running..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID_1" "$INSTANCE_ID_2" "$INSTANCE_ID_3"

# Get private IPs
PRIVATE_IP_1=$(aws ec2 describe-instances \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID_1" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

PRIVATE_IP_2=$(aws ec2 describe-instances \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID_2" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

PRIVATE_IP_3=$(aws ec2 describe-instances \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID_3" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

echo ""
echo "=== Instance Information ==="
echo "Instance 1 (no user-data):    $INSTANCE_ID_1 at $PRIVATE_IP_1"
echo "Instance 2 (empty user-data): $INSTANCE_ID_2 at $PRIVATE_IP_2"
echo "Instance 3 (invalid YAML):    $INSTANCE_ID_3 at $PRIVATE_IP_3"

echo ""
echo "=== Testing Instructions ==="
echo "Wait 3-4 minutes for all instances to fully boot, then test from bastion:"
echo ""
echo "1. Test Talm discovery on all instances:"
echo "   talm template -e $PRIVATE_IP_1 -n $PRIVATE_IP_1 -t templates/controlplane.yaml -i > nodes/node1.yaml"
echo "   talm template -e $PRIVATE_IP_2 -n $PRIVATE_IP_2 -t templates/controlplane.yaml -i > nodes/node2.yaml"
echo "   talm template -e $PRIVATE_IP_3 -n $PRIVATE_IP_3 -t templates/controlplane.yaml -i > nodes/node3.yaml"
echo ""
echo "2. Test basic Talos API connectivity:"
echo "   talosctl -n $PRIVATE_IP_1 -e $PRIVATE_IP_1 --talosconfig=/dev/null disks"
echo "   talosctl -n $PRIVATE_IP_2 -e $PRIVATE_IP_2 --talosconfig=/dev/null disks"  
echo "   talosctl -n $PRIVATE_IP_3 -e $PRIVATE_IP_3 --talosconfig=/dev/null disks"
echo ""
echo "3. Check console output for maintenance mode indicators:"
echo "   aws ec2 get-console-output --instance-id $INSTANCE_ID_1 --region $REGION"
echo "   aws ec2 get-console-output --instance-id $INSTANCE_ID_2 --region $REGION"
echo "   aws ec2 get-console-output --instance-id $INSTANCE_ID_3 --region $REGION"

# Clean up temp files
rm -f empty-user-data.txt invalid-user-data.yaml

echo ""
echo "=== Summary ==="
echo "Three instances launched with different approaches to force maintenance mode:"
echo "- No user-data: Most likely to work as Talos should default to maintenance mode"
echo "- Empty user-data: May still try to parse as config"
echo "- Invalid YAML: Should fail parsing and fallback to maintenance mode"
echo ""
echo "Test all three approaches to see which one puts Talos into discoverable maintenance mode."