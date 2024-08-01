provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# Check if the DynamoDB table exists
data "aws_dynamodb_table" "existing_table" {
  count = var.dynamodb_table_exists ? 1 : 0
  name  = var.dynamodb_table_name
}

# Local variable to check if the DynamoDB table exists
locals {
  dynamodb_table_exists = length(data.aws_dynamodb_table.existing_table) > 0
}

# Create DynamoDB table if it does not exist
resource "aws_dynamodb_table" "todo_table" {
  count        = local.dynamodb_table_exists ? 0 : 1
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Check if IAM Role already exists
data "aws_iam_role" "existing_role" {
  count = var.lambda_role_exists ? 1 : 0
  name  = var.lambda_role_name
}

# Local variable to check if the IAM role exists
locals {
  iam_role_exists = try(length(data.aws_iam_role.existing_role[0].id) > 0, false)
}

# Create IAM Role for Lambda if it does not exist
resource "aws_iam_role" "lambda_exec" {
  count = local.iam_role_exists ? 0 : 1
  name  = var.lambda_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy Attachment for Lambda
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  count      = local.iam_role_exists ? 0 : 1
  role       = aws_iam_role.lambda_exec[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for S3 Access
resource "aws_iam_role_policy" "s3_access" {
  count = local.iam_role_exists ? 0 : 1
  name  = var.lambda_s3_policy_name
  role  = aws_iam_role.lambda_exec[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.s3_todo_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.s3_todo_bucket.bucket}/*"
        ]
      }
    ]
  })
}

# IAM Policy for DynamoDB Access
resource "aws_iam_role_policy" "dynamodb_access" {
  count = local.iam_role_exists ? 0 : 1
  name  = var.lambda_dynamodb_policy_name
  role  = aws_iam_role.lambda_exec[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:Scan",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        Resource = [
          "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}"
        ]
      }
    ]
  })
}

# Generate a random string to append to the bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket
resource "aws_s3_bucket" "s3_todo_bucket" {
  bucket        = "${var.project_name}-${var.environment}-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-bucket"
    Environment = var.environment
  }
}


data "aws_acm_certificate" "existing_cert" {
  count    = var.certificate_exists ? 0 : 1
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

locals {
  certificate_exists = length(data.aws_acm_certificate.existing_cert[0].arn) > 0
}

# This local variable sets certificate_arn to the ARN of the existing 
# certificate if it exists; otherwise, it sets it to an empty string.
locals {
  certificate_arn = var.certificate_exists ? data.aws_acm_certificate.existing_cert[0].arn : ""
}

# This resource block creates a new ACM certificate if 
# var.certificate_exists is false.
# Conditionally create ACM certificate if it does not exist
resource "aws_acm_certificate" "cert" {
  count             = local.certificate_exists ? 0 : 1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "Terraform-managed"
  }
}

# This local variable sets cert_validation_options to the 
# validation options of the created ACM certificate if it exists; 
# otherwise, it sets it to an empty list.
locals {
  cert_validation_options = length(aws_acm_certificate.cert) > 0 ? aws_acm_certificate.cert[0].domain_validation_options : []
}

# This block creates Route 53 DNS validation records for 
# each domain validation option if the certificate was created.
resource "aws_route53_record" "cert_validation" {
  for_each = { for dvo in local.cert_validation_options : dvo.domain_name => {
    name    = dvo.resource_record_name
    type    = dvo.resource_record_type
    value   = dvo.resource_record_value
    zone_id = var.zone_id
  } }

  name    = each.value.name
  type    = each.value.type
  zone_id = each.value.zone_id
  records = [each.value.value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  count                   = length(aws_acm_certificate.cert) > 0 ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Lambda Function
resource "aws_lambda_function" "todo_lambda" {
  function_name    = var.lambda_app_name
  role             = aws_iam_role.lambda_exec[0].arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = filebase64sha256(var.lambda_zip_file)
  filename         = var.lambda_zip_file

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
      S3_BUCKET_NAME      = aws_s3_bucket.s3_todo_bucket.bucket
    }
  }
}

# This block checks if an API Gateway REST API with the specified name exists 
data "aws_api_gateway_rest_api" "existing_api" {
  count = var.api_stage_exists ? 1 : 0
  name  = var.api_gateway_api_name
}

# and sets a local variable accordingly.
locals {
  api_stage_exists = length(data.aws_api_gateway_rest_api.existing_api) > 0
}

# Create API Gateway REST API if it Does Not Exist
resource "aws_api_gateway_rest_api" "todo_api" {
  count       = local.api_stage_exists ? 0 : 1
  name        = var.api_gateway_api_name
  description = "API for Todo Application"
}

resource "aws_api_gateway_resource" "todo_resource" {
  count       = local.api_stage_exists ? 0 : 1
  rest_api_id = aws_api_gateway_rest_api.todo_api[0].id
  parent_id   = aws_api_gateway_rest_api.todo_api[0].root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_method" {
  count         = local.api_stage_exists ? 0 : 1
  rest_api_id   = aws_api_gateway_rest_api.todo_api[0].id
  resource_id   = aws_api_gateway_resource.todo_resource[0].id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy_integration" {
  count                   = local.api_stage_exists ? 0 : 1
  rest_api_id             = aws_api_gateway_rest_api.todo_api[0].id
  resource_id             = aws_api_gateway_resource.todo_resource[0].id
  http_method             = aws_api_gateway_method.proxy_method[0].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.todo_lambda.arn}/invocations"
}

resource "aws_api_gateway_deployment" "todo_api_deployment" {
  depends_on  = [aws_api_gateway_integration.proxy_integration]
  rest_api_id = aws_api_gateway_rest_api.todo_api[0].id
  stage_name  = "dev"
}

resource "aws_api_gateway_stage" "todo_stage" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.todo_api[0].id
  deployment_id = aws_api_gateway_deployment.todo_api_deployment.id
}

resource "aws_api_gateway_domain_name" "todo_domain" {
  count           = local.api_stage_exists ? 0 : 1
  domain_name     = var.domain_name
  certificate_arn = local.certificate_arn
}

resource "aws_api_gateway_base_path_mapping" "todo_base_path_mapping" {
  count       = local.api_stage_exists ? 0 : 1
  api_id      = aws_api_gateway_rest_api.todo_api[0].id
  stage_name  = aws_api_gateway_stage.todo_stage.stage_name
  domain_name = aws_api_gateway_domain_name.todo_domain[0].domain_name
}

resource "aws_route53_record" "api" {
  count   = local.api_stage_exists ? 0 : 1
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.todo_domain[0].cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.todo_domain[0].cloudfront_zone_id
    evaluate_target_health = false
  }
}
