"""
Sunkworks Rollback Handler Lambda
Automated rollback when CozyStack bootstrap fails
"""

import json
import os
import time
import urllib.request
import boto3

ec2 = boto3.client('ec2')
autoscaling = boto3.client('autoscaling')


def handler(event, context):
    """Handle rollback triggered by CloudWatch alarm or Step Functions."""
    
    print(f"Rollback triggered: {json.dumps(event)}")
    
    environment = os.environ.get('ENVIRONMENT', 'chaos')
    rollback_snapshot_id = os.environ.get('ROLLBACK_SNAPSHOT_ID', '')
    slack_webhook = os.environ.get('SLACK_WEBHOOK_URL', '')
    
    start_time = time.time()
    rollback_status = {
        'success': False,
        'actions': [],
        'errors': []
    }
    
    try:
        # Step 1: Identify affected instances
        instances = get_affected_instances(environment)
        rollback_status['actions'].append(f"Found {len(instances)} affected instances")
        
        # Step 2: Stop affected instances
        if instances:
            stop_instances(instances)
            rollback_status['actions'].append("Stopped affected instances")
        
        # Step 3: Restore from snapshot if available
        if rollback_snapshot_id:
            restore_from_snapshot(instances, rollback_snapshot_id)
            rollback_status['actions'].append(f"Restored from snapshot {rollback_snapshot_id}")
        
        # Step 4: Restart instances
        if instances:
            start_instances(instances)
            rollback_status['actions'].append("Restarted instances")
        
        # Step 5: Wait for health check
        healthy = wait_for_health(instances, timeout=300)
        if healthy:
            rollback_status['actions'].append("Health check passed")
            rollback_status['success'] = True
        else:
            rollback_status['errors'].append("Health check failed after rollback")
        
    except Exception as e:
        rollback_status['errors'].append(str(e))
        print(f"Rollback error: {e}")
    
    elapsed_time = time.time() - start_time
    rollback_status['duration_seconds'] = elapsed_time
    
    # Notify via Slack
    if slack_webhook:
        notify_slack(slack_webhook, rollback_status, environment)
    
    return rollback_status


def get_affected_instances(environment):
    """Get instances tagged for this environment."""
    response = ec2.describe_instances(
        Filters=[
            {'Name': 'tag:Project', 'Values': ['sunkworks-chaos']},
            {'Name': 'tag:Environment', 'Values': [environment]},
            {'Name': 'instance-state-name', 'Values': ['running', 'stopped']}
        ]
    )
    
    instances = []
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instances.append(instance['InstanceId'])
    
    return instances


def stop_instances(instance_ids):
    """Stop the specified instances."""
    if not instance_ids:
        return
    
    ec2.stop_instances(InstanceIds=instance_ids)
    
    # Wait for instances to stop
    waiter = ec2.get_waiter('instance_stopped')
    waiter.wait(
        InstanceIds=instance_ids,
        WaiterConfig={'Delay': 10, 'MaxAttempts': 30}
    )


def start_instances(instance_ids):
    """Start the specified instances."""
    if not instance_ids:
        return
    
    ec2.start_instances(InstanceIds=instance_ids)
    
    # Wait for instances to be running
    waiter = ec2.get_waiter('instance_running')
    waiter.wait(
        InstanceIds=instance_ids,
        WaiterConfig={'Delay': 10, 'MaxAttempts': 30}
    )


def restore_from_snapshot(instance_ids, snapshot_id):
    """Restore EBS volumes from snapshot for rollback."""
    if not instance_ids or not snapshot_id:
        return
    
    for instance_id in instance_ids:
        # Get instance details
        response = ec2.describe_instances(InstanceIds=[instance_id])
        instance = response['Reservations'][0]['Instances'][0]
        az = instance['Placement']['AvailabilityZone']
        
        # Find attached volumes with Role=etcd tag
        for bdm in instance.get('BlockDeviceMappings', []):
            volume_id = bdm['Ebs']['VolumeId']
            
            # Check if this is an etcd volume
            vol_response = ec2.describe_volumes(VolumeIds=[volume_id])
            volume = vol_response['Volumes'][0]
            
            volume_tags = {t['Key']: t['Value'] for t in volume.get('Tags', [])}
            if volume_tags.get('Role') != 'etcd':
                continue
            
            device = bdm['DeviceName']
            
            # Detach old volume
            ec2.detach_volume(VolumeId=volume_id, Force=True)
            
            # Create new volume from snapshot
            new_vol = ec2.create_volume(
                AvailabilityZone=az,
                SnapshotId=snapshot_id,
                VolumeType='gp3',
                TagSpecifications=[{
                    'ResourceType': 'volume',
                    'Tags': [
                        {'Key': 'Name', 'Value': f'rollback-{instance_id}'},
                        {'Key': 'Role', 'Value': 'etcd'},
                        {'Key': 'Project', 'Value': 'sunkworks-chaos'}
                    ]
                }]
            )
            
            # Wait for volume to be available
            waiter = ec2.get_waiter('volume_available')
            waiter.wait(VolumeIds=[new_vol['VolumeId']])
            
            # Attach new volume
            ec2.attach_volume(
                VolumeId=new_vol['VolumeId'],
                InstanceId=instance_id,
                Device=device
            )


def wait_for_health(instance_ids, timeout=300):
    """Wait for instances to pass health checks."""
    if not instance_ids:
        return True
    
    start = time.time()
    while time.time() - start < timeout:
        response = ec2.describe_instance_status(
            InstanceIds=instance_ids,
            IncludeAllInstances=True
        )
        
        all_healthy = True
        for status in response['InstanceStatuses']:
            if status['InstanceStatus']['Status'] != 'ok':
                all_healthy = False
                break
            if status['SystemStatus']['Status'] != 'ok':
                all_healthy = False
                break
        
        if all_healthy:
            return True
        
        time.sleep(10)
    
    return False


def notify_slack(webhook_url, status, environment):
    """Send rollback notification to Slack."""
    
    emoji = "✅" if status['success'] else "❌"
    color = "good" if status['success'] else "danger"
    
    message = {
        "attachments": [{
            "color": color,
            "title": f"{emoji} Sunkworks Rollback - {environment}",
            "fields": [
                {
                    "title": "Status",
                    "value": "Success" if status['success'] else "Failed",
                    "short": True
                },
                {
                    "title": "Duration",
                    "value": f"{status.get('duration_seconds', 0):.1f}s",
                    "short": True
                },
                {
                    "title": "Actions",
                    "value": "\n".join(status.get('actions', [])) or "None",
                    "short": False
                }
            ]
        }]
    }
    
    if status.get('errors'):
        message["attachments"][0]["fields"].append({
            "title": "Errors",
            "value": "\n".join(status['errors']),
            "short": False
        })
    
    try:
        req = urllib.request.Request(
            webhook_url,
            data=json.dumps(message).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req)
    except Exception as e:
        print(f"Slack notification failed: {e}")
