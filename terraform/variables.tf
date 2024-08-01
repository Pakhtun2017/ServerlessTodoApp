variable "project_name" {
  description = "The name of the Project"
  type        = string
  default     = "serverless-todo-app"
}

variable "region" {
  description = "The AWS region where resources are created"
  type        = string
}

variable "environment" {
  description = "The environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  type        = string
  default     = "TodoItems"
}

# Variable to define if DynamoDB table exists
variable "dynamodb_table_exists" {
  description = "Set to true if the DynamoDB table exists; otherwise, set to false."
  type        = bool
  default     = false
}

variable "lambda_app_name" {
  description = "The name of the Lambda function"
  type        = string
  default     = "todo-app-lambda"
}

variable "lambda_zip_file" {
  description = "Path to the lambda function zip file"
  type        = string
}

variable "domain_name" {
  description = "The custom domain name for the API"
  type        = string
  default     = "api.tolstoynow.com"
}

variable "zone_id" {
  description = "The Route 53 Hosted Zone ID"
  type        = string
  default     = "Z01416203FPOMCB5W0JRJ"
}

variable "lambda_role_name" {
  description = "Name of Lambda role"
  type        = string
  default     = "todo-app-lambda-role"
}

variable "lambda_role_exists" {
  description = "Set to true if lambda role exists; otherwise, set to false."
  type        = bool
  default     = false
}

variable "lambda_s3_policy_name" {
  description = "Lambda S3 Policy name"
  type        = string
  default     = "lambda-s3-access-policy"
}

variable "lambda_dynamodb_policy_name" {
  description = "Lambda DynamoDB Policy name"
  type        = string
  default     = "lambda-dynamodb-access-policy"
}

variable "api_gateway_api_name" {
  description = "API Gateway API name"
  type        = string
  default     = "TodoAPI"
}

variable "stage_name" {
  description = "API Gateway API Stage name"
  type        = string
  default     = "dev" 
}

# Variable to define if API Stage exists
variable "api_stage_exists" {
  description = "Set to true if the API Stage exists; otherwise, set to false."
  type        = bool
  default     = false
}

variable "certificate_exists" {
  description = "A boolean to determine if the certificate exists"
  default     = false
}