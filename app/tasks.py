import boto3
import uuid
import os
from datetime import datetime

# Get the DynamoDB table name from an environment variable
table_name = os.getenv('DYNAMODB_TABLE_NAME', 'TodoItems')

# Creates a DynamoDB resource object (dynamodb) using Boto3.
dynamodb = boto3.resource('dynamodb')
# Access the DynamoDB table using the environment variable
table = dynamodb.Table(table_name)

def add_task(task):
    # Convert task to lowercase for case-insensitive comparison
    lower_task = task.lower()
    
    # Check if the task already exists (case-insensitive)
    # scan method is  provided by boto3.resource
    response = table.scan(
        FilterExpression=boto3.dynamodb.conditions.Attr('lower_task').eq(lower_task)
    )
    
    if not response['Items']:
        # If the task does not exist, add it
        table.put_item(Item={
            'id': str(uuid.uuid4()), 
            'task': task, 
            'lower_task': lower_task,
            'timestamp': datetime.utcnow().isoformat() # Add current timestamp
        })

def list_tasks():
    response = table.scan()
    # Sort tasks by timestamp to ensure order of entry
    tasks = sorted(response['Items'], key=lambda item: item['timestamp'])
    return [{'id': item['id'], 'task': item['task']} for item in tasks]

def remove_task(task_id):
    table.delete_item(Key={'id': task_id})
