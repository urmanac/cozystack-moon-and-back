#!/bin/bash
set -euo pipefail

# Force Talos into maintenance mode for Talm discovery
# The key insight is that we need to prevent Talos from finding any valid config
# and ensure it falls back to maintenance mode

REGION="eu-west-1"
SUBNET_ID="subnet-07a140ab2b20bf89b"
SECURITY_GROUP_ID="sg-0e2d7e8c5f9b8a1d3"
AMI_ID="ami-0d0b5ac770722d15e"  # Official Talos v1.11.1 ARM64
INSTANCE_TYPE="t4g.small"
KEY_NAME="yebyen-key-pair"

echo "=== Forcing Talos into Maintenance Mode for Talm Discovery ==="

# Create user-data that explicitly forces maintenance mode
# This works by providing invalid/empty configuration that forces fallback
cat > maintenance-mode-user-data.yaml << 'EOF'
#cloud-config
# Empty cloud-config to force Talos maintenance mode
# When Talos can't parse this as valid machine config, it should enter maintenance mode
EOF

echo "Creating instance with empty/invalid config to force maintenance mode..."

# Launch instance with invalid config to force maintenance mode
INSTANCE_ID=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --subnet-id "$SUBNET_ID" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --user-data file://maintenance-mode-user-data.yaml \
    --block-device-mappings '[{
        "DeviceName": "/dev/xvda",
        "Ebs": {
            "VolumeSize": 20,
            "VolumeType": "gp3",
            "DeleteOnTermination": true
        }
    }]' \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=talos-maintenance-forced}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance launched: $INSTANCE_ID"

# Wait for instance to be running
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

# Get private IP
PRIVATE_IP=$(aws ec2 describe-instances \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

echo "Instance is running at: $PRIVATE_IP"

echo ""
echo "=== Next Steps for Talm Discovery ==="
echo "1. Wait 2-3 minutes for Talos to fully boot and enter maintenance mode"
echo "2. Test connectivity with: talosctl -n $PRIVATE_IP -e $PRIVATE_IP get disks --talosconfig=/dev/null"
echo "3. Run Talm discovery: talm -n $PRIVATE_IP -e $PRIVATE_IP template -t templates/controlplane.yaml -i > nodes/node1.yaml"
echo ""
echo "If the node is not in maintenance mode, we may need to try a different approach:"
echo "- Boot without any user-data at all"
echo "- Use a custom kernel parameter to force maintenance mode"
echo "- Or modify the AMI launch parameters"

# Clean up temp file
rm -f maintenance-mode-user-data.yaml

echo "Instance ID: $INSTANCE_ID"
echo "Private IP: $PRIVATE_IP"