provider "aws" {
  region = var.region
}

# DynamoDB Table
resource "aws_dynamodb_table" "todo_table" {
  name           = "TodoTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# S3 Bucket
resource "aws_s3_bucket" "pashtun_bucket" {
  bucket_prefix = var.s3_bucket
  force_destroy = true
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "todo-app-lambda-role"
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
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for S3 Access
resource "aws_iam_role_policy" "s3_access" {
  name = "lambda-s3-access-policy"
  role = aws_iam_role.lambda_exec.id

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
          "arn:aws:s3:::your-bucket-name",
          "arn:aws:s3:::your-bucket-name/*"
        ]
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "todo_lambda" {
  function_name = "todo-app-lambda"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30

  source_code_hash = filebase64sha256("lambda_function.zip")
  filename         = "lambda_function.zip"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.todo_table.name
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
  depends_on = [aws_api_gateway_integration.proxy_integration]
  rest_api_id = aws_api_gateway_rest_api.todo_api.id
  stage_name  = "dev"
}

resource "aws_api_gateway_stage" "todo_stage" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.todo_api.id
  deployment_id = aws_api_gateway_deployment.todo_api_deployment.id
}

resource "aws_api_gateway_domain_name" "todo_domain" {
  domain_name = var.domain_name
  certificate_arn = aws_acm_certificate.cert.arn
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
