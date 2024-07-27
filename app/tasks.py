import boto3
import uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TodoTable')

def add_task(task):
    table.put_item(Item={'id': str(uuid.uuid4()), 'task': task})

def list_tasks():
    response = table.scan()
    return [{'id': item['id'], 'task': item['task']} for item in response['Items']]

def remove_task(task_id):
    table.delete_item(Key={'id': task_id})
