from flask import Flask, request, jsonify
from flask_awsgi import AWsgi
from tasks import add_task, list_tasks, remove_task

# Initialize Flask application
app = Flask(__name__)

@app.route('/')
def index():
    tasks = list_tasks()
    return jsonify(tasks)

@app.route('/add', methods=['POST'])
def add():
    task = request.json.get('task')
    if not task:
        return jsonify({'error': 'Task is required'}), 400

    add_task(task)
    return jsonify({'message': 'Task added successfully'})

@app.route('/remove/<string:task_id>', methods=['DELETE'])
def remove(task_id):
    remove_task(task_id)
    return jsonify({'message': 'Task removed successfully'})

# Lambda handler
def lambda_handler(event, context):
    return AWsgi(app).handle(event, context)

if __name__ == '__main__':
    app.run(debug=True)
