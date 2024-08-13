output "dynamodb_table_name" {
  value = length(aws_dynamodb_table.todo_table) > 0 ? aws_dynamodb_table.todo_table[0].name : "TodoItems"
}

output "iam_role_name" {
  value = length(aws_iam_role.lambda_exec) > 0 ? aws_iam_role.lambda_exec[0].name : "todo-app-lambda-role"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.s3_todo_bucket.bucket
}

output "certificate_arn" {
  value = length(aws_acm_certificate.cert) > 0 ? aws_acm_certificate.cert[0].arn : data.aws_acm_certificate.existing_cert[0].arn
}

output "region" {
  value = var.region
}

output "lambda_role_arn" {
  value = length(aws_iam_role.lambda_exec) > 0 ? aws_iam_role.lambda_exec[0].arn : data.aws_iam_role.existing_role.arn
}

output "lambda_role_name" {
  value = length(aws_iam_role.lambda_exec) > 0 ? aws_iam_role.lambda_exec[0].name : data.aws_iam_role.existing_role.name
}

output "domain_name" {
  value = var.domain_name
}
