from app import app
from flask import request, render_template, redirect, url_for
from tasks import add_task, list_tasks, remove_task

@app.route('/')
def index():
    tasks = list_tasks()
    return render_template('index.html', tasks=tasks)

@app.route('/add', methods=['POST'])
def add():
    task = request.form.get('task')
    add_task(task)
    return redirect(url_for('index'))

@app.route('/remove/<string:task_id>')
def remove(task_id):
    remove_task(task_id)
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
