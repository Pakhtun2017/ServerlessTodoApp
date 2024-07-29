provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# Check if DynamoDB table already exists
data "aws_dynamodb_table" "existing_table" {
  name = var.dynamodb_table_name
}

resource "aws_dynamodb_table" "todo_table" {
  count        = length(data.aws_dynamodb_table.existing_table.id) > 0 ? 0 : 1
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
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

# Check if IAM Role already exists
data "aws_iam_role" "existing_role" {
  name = "todo-app-lambda-role"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  count = length(data.aws_iam_role.existing_role.arn) > 0 ? 0 : 1
  name  = "todo-app-lambda-role"
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
  count      = length(data.aws_iam_role.existing_role.arn) > 0 ? 0 : 1
  role       = aws_iam_role.lambda_exec[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for S3 Access
resource "aws_iam_role_policy" "s3_access" {
  count = length(data.aws_iam_role.existing_role.arn) > 0 ? 0 : 1
  name  = "lambda-s3-access-policy"
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
  count = length(data.aws_iam_role.existing_role.arn) > 0 ? 0 : 1
  name  = "lambda-dynamodb-access-policy"
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

# Data source to check for existing ACM certificate
data "aws_acm_certificate" "existing_cert" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

# Conditionally create ACM certificate if it does not exist
resource "aws_acm_certificate" "cert" {
  count             = length(data.aws_acm_certificate.existing_cert.arn) > 0 ? 0 : 1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "Terraform-managed"
  }
}

# Create a list of DNS validation records if certificate is created
locals {
  cert_validation_options = length(aws_acm_certificate.cert) > 0 ? aws_acm_certificate.cert[0].domain_validation_options : []
}

# Route 53 record for certificate validation
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

# Validate the ACM certificate if created
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
  source_code_hash = filebase64sha256("../package/lambda_function.zip")
  filename         = var.lambda_zip_file

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
      S3_BUCKET_NAME      = aws_s3_bucket.s3_todo_bucket.bucket
    }
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "todo_api" {
  name        = "TodoAPI"
  description = "API for Todo Application"
}

resource "aws_api_gateway_resource" "todo_resource" {
  rest_api_id = aws_api_gateway_rest_api.todo_api.id
  parent_id   = aws_api_gateway_rest_api.todo_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.todo_api.id
  resource_id   = aws_api_gateway_resource.todo_resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.todo_api.id
  resource_id             = aws_api_gateway_resource.todo_resource.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.todo_lambda.arn}/invocations"
}

resource "aws_api_gateway_deployment" "todo_api_deployment" {
  depends_on  = [aws_api_gateway_integration.proxy_integration]
  rest_api_id = aws_api_gateway_rest_api.todo_api.id
  stage_name  = "dev"
}

resource "aws_api_gateway_stage" "todo_stage" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.todo_api.id
  deployment_id = aws_api_gateway_deployment.todo_api_deployment.id
}

resource "aws_api_gateway_domain_name" "todo_domain" {
  domain_name     = var.domain_name
  certificate_arn = length(aws_acm_certificate.cert) > 0 ? aws_acm_certificate.cert[0].arn : data.aws_acm_certificate.existing_cert.arn
}

resource "aws_api_gateway_base_path_mapping" "todo_base_path_mapping" {
  api_id      = aws_api_gateway_rest_api.todo_api.id
  stage_name  = aws_api_gateway_stage.todo_stage.stage_name
  domain_name = aws_api_gateway_domain_name.todo_domain.domain_name
}

resource "aws_route53_record" "api" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.todo_domain.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.todo_domain.cloudfront_zone_id
    evaluate_target_health = false
  }
}
