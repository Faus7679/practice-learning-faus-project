import json
import boto3
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS services
sns = boto3.client('sns')

def handler(event, context):
    """
    Lambda function to process Jenkins build notifications
    and send alerts via SNS
    """
    
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Process the build event
        build_info = extract_build_info(event)
        
        # Send notification if needed
        if should_notify(build_info):
            send_notification(build_info)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Build notification processed successfully',
                'build_info': build_info
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing build notification: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error processing build notification',
                'error': str(e)
            })
        }

def extract_build_info(event):
    """Extract build information from the event"""
    
    # Default build info structure
    build_info = {
        'project': '${PROJECT_NAME}',
        'environment': '${ENVIRONMENT}',
        'status': 'unknown',
        'timestamp': datetime.utcnow().isoformat(),
        'commit_hash': 'unknown',
        'branch': 'unknown',
        'build_number': 'unknown'
    }
    
    # Try to extract from Jenkins webhook format
    if 'Records' in event:
        # SNS message format
        for record in event['Records']:
            if record.get('EventSource') == 'aws:sns':
                message = json.loads(record['Sns']['Message'])
                build_info.update(message)
    elif 'build' in event:
        # Direct Jenkins format
        build_info.update({
            'status': event.get('build', {}).get('status', 'unknown'),
            'build_number': event.get('build', {}).get('number', 'unknown'),
            'commit_hash': event.get('build', {}).get('scm', {}).get('commit', 'unknown'),
            'branch': event.get('build', {}).get('scm', {}).get('branch', 'unknown')
        })
    
    return build_info

def should_notify(build_info):
    """Determine if a notification should be sent"""
    
    # Always notify on failures
    if build_info['status'] in ['FAILURE', 'ABORTED', 'UNSTABLE']:
        return True
    
    # Notify on success for production environment
    if build_info['environment'] == 'prod' and build_info['status'] == 'SUCCESS':
        return True
    
    # Notify on first success after failure (requires state tracking)
    # This would need DynamoDB or similar for state persistence
    
    return False

def send_notification(build_info):
    """Send SNS notification about the build"""
    
    # Construct the message
    subject = f"Build {build_info['status']}: {build_info['project']}"
    
    message_body = f"""
Build Notification - {build_info['project']}

Status: {build_info['status']}
Environment: {build_info['environment']}
Build Number: {build_info['build_number']}
Branch: {build_info['branch']}
Commit: {build_info['commit_hash']}
Timestamp: {build_info['timestamp']}

Project: {build_info['project']}
"""
    
    # Send to SNS topic
    response = sns.publish(
        TopicArn='${sns_topic_arn}',
        Message=message_body,
        Subject=subject
    )
    
    logger.info(f"SNS notification sent: {response['MessageId']}")
    
    return response