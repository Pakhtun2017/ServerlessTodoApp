ServerlessTodoApp

Overview

ServerlessTodoApp is a serverless Todo application built using Flask, AWS Lambda, API Gateway, Terraform, and Jenkins. The application allows users to manage their tasks seamlessly through a web interface. This project emphasizes a serverless architecture, packaging the Lambda function as a zip file rather than using Docker images.

Features

* Add, list, and remove tasks.
* Serverless architecture using AWS Lambda and API Gateway.
* Infrastructure as Code (IaC) using Terraform.
* Continuous Integration and Continuous Deployment (CI/CD) pipeline using Jenkins.
* Secure and scalable using AWS services.

Architecture

1. Frontend: Flask application serving HTML pages.
2. Backend: AWS Lambda functions triggered by API Gateway.
3. Database: DynamoDB table for storing tasks.
4. CI/CD: Jenkins pipeline automating the deployment process.
5. IaC: Terraform scripts for provisioning AWS resources.

Workflow

High-Level Workflow

1. User Interaction: Users interact with the application via a web browser.
2. API Gateway: API Gateway routes the requests to the appropriate AWS Lambda function.
3. Lambda Function: The Lambda function executes the application logic (add, list, remove tasks).
4. DynamoDB: The Lambda function interacts with DynamoDB to store and retrieve tasks.

Detailed Workflow

1. User Requests:
    * Add Task: User submits a task via the web interface.
    * List Tasks: User requests the list of tasks.
    * Remove Task: User deletes a task from the list.
2. API Gateway: Receives the HTTP request and routes it to the corresponding Lambda function.
3. Lambda Function:
    * Handler: The handler function processes the request.
    * Business Logic: The function contains logic to interact with DynamoDB (add, list, remove).
4. DynamoDB: The database stores task data.

CI/CD Pipeline

1. Code Checkout: Jenkins pulls the latest code from GitHub.
2. Environment Setup: Sets up Python environment and installs dependencies.
3. Package Lambda: Packages the Lambda function code into a zip file.
4. Upload to S3: Uploads the Lambda zip file to an S3 bucket.
5. Terraform Apply: Runs Terraform to provision AWS resources and deploy the Lambda function.

Getting Started

Prerequisites

* AWS Account
* AWS CLI configured
* Terraform installed
* Jenkins installed
* Python 3.12 installed

Installation

1. Clone the repository:
git clone https://github.com/yourusername/ServerlessTodoApp.git
cd ServerlessTodoApp

2. Set up virtual environment:
python3.12 -m venv venv
source venv/bin/activate
pip install -r app/requirements.txt

3. Configure AWS CLI:
aws configure

4. Initialize Terraform:
cd terraform
terraform init

Running Locally

1. Start Flask application:
cd app
flask run

2. Access the application:
Open your browser and navigate to http://127.0.0.1:5000


Deployment

1. Package Lambda Function:
cd app
zip -r lambda_function.zip app.py lambda_function.py tasks.py venv/lib/python3.12/site-packages

2. Upload to S3:
aws s3 cp lambda_function.zip s3://your-bucket-name/lambda_function.zip

3. Run Terraform Apply:
cd terraform
terraform apply -auto-approve \
-var="region=us-east-1" \
-var="domain_name=api.tolstoynow.com" \
-var="zone_id=YOUR_ROUTE_53_ZONE_ID"

Contributing
Contributions are welcome! Please fork the repository and use a feature branch. Pull requests are accepted.

License
This project is licensed under the MIT License. See the LICENSE file for details.

