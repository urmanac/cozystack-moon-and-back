#!/bin/bash

# Cleanup script to terminate all EC2 instances
# Use with caution - this will terminate ALL instances in the region!

set -e

echo "🧹 Starting EC2 cleanup process..."

# Get all instance IDs
INSTANCE_IDS=$(aws ec2 describe-instances \
    --region eu-west-1 \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text \
    --filters Name=instance-state-name,Values=running,pending,stopping,stopped)

if [ -z "$INSTANCE_IDS" ]; then
    echo "✅ No instances found to terminate"
    exit 0
fi

echo "🔍 Found instances to terminate:"
for instance_id in $INSTANCE_IDS; do
    # Get instance details
    INSTANCE_INFO=$(aws ec2 describe-instances \
        --region eu-west-1 \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' \
        --output text)
    
    echo "  - $INSTANCE_INFO"
done

echo ""
echo "⚠️  WARNING: This will terminate ALL instances listed above!"
echo "Press Enter to continue or Ctrl+C to cancel..."
read

echo "🔥 Terminating instances..."
aws ec2 terminate-instances \
    --region eu-west-1 \
    --instance-ids $INSTANCE_IDS

echo "✅ Termination requests sent for all instances"
echo "🕐 Instances are now shutting down..."

# Wait for all instances to reach terminated state
echo "⏳ Waiting for instances to terminate..."
aws ec2 wait instance-terminated \
    --region eu-west-1 \
    --instance-ids $INSTANCE_IDS

echo "🎉 All instances have been successfully terminated!"
echo "💰 Cleanup complete - no more EC2 charges!"