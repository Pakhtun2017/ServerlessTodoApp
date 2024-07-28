variable "project_name" {
  description = "The name of the Project"
  type        = string
  default     = "ServerlessTodoApp"
}

variable "region" {
  description = "The AWS region where resources are created"
  type        = string
  default     = "us-east-1"
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

variable "lambda_app_name" {
  description = "The name of the Lambda function"
  type        = string
  default     = "todo-app-lambda"
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
