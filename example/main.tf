locals {
  circuitbreakable_service_name = "example_service"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_id" "stack_id" {
  byte_length = 8
}

resource "aws_ssm_parameter" "service_state_paramater" {
  name  = "serviceState"
  type  = "String"
  value = "OK"
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_cloudwatch_log_group" "circuitbreaker_healthcheck_function_loggroup" {
  name              = "/aws/lambda/circuitbreaker_healthcheck_function_${random_id.stack_id.hex}"
  retention_in_days = 1
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_log_group" "circuitbreaker_downstream_function_loggroup" {
  name              = "/aws/lambda/circuitbreaker_downstream_function_${random_id.stack_id.hex}"
  retention_in_days = 1
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_dynamodb_table" "circuitbreaker_services_table" {
  name         = "circuitbreaker_services_table_${random_id.stack_id.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "serviceName"
  attribute {
    name = "serviceName"
    type = "S"
  }
}

resource "aws_lambda_layer_version" "circuitbreaker_lambda_layer" {
  filename            = "functions/.build/src/out/node_package.zip"
  layer_name          = "circuitbreaker_lambda_layer_${random_id.stack_id.hex}"
  compatible_runtimes = ["nodejs18.x"]
  source_code_hash    = filebase64sha256("functions/.build/src/out/node_package.zip")
}

data "aws_iam_policy_document" "circuitbreaker_functions_assumerole_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "circuitbreaker_functions_permissions_policy" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.service_state_paramater.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "circuitbreaker_functions_permissions_policy" {
  policy = data.aws_iam_policy_document.circuitbreaker_functions_permissions_policy.json
  name   = "circuitbreaker_functions_permissions_policy"
}

resource "aws_iam_role" "circuitbreaker_functions_role" {
  name               = "circuitbreaker_example_service_functions_role_${random_id.stack_id.hex}"
  assume_role_policy = data.aws_iam_policy_document.circuitbreaker_functions_assumerole_policy.json
}

resource "aws_iam_policy_attachment" "circuitbreaker_functions_role_attachments" {

  name       = "circuitbreaker_functions_role_attachments_attachments"
  policy_arn = aws_iam_policy.circuitbreaker_functions_permissions_policy.arn
  roles      = [aws_iam_role.circuitbreaker_functions_role.name]
}

resource "aws_iam_policy_attachment" "circuitbreaker_functions_role_basiclambdaexecution_attachment" {
  name       = "circuitbreaker_functions_role_basiclambdaexecution_attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  roles      = [aws_iam_role.circuitbreaker_functions_role.name]
}

resource "aws_lambda_function" "circuitbreaker_downstream_function" {
  depends_on       = [aws_cloudwatch_log_group.circuitbreaker_downstream_function_loggroup]
  filename         = "functions/.build/src/out/downstream-handler.zip"
  function_name    = "circuitbreaker_downstream_function_${random_id.stack_id.hex}"
  handler          = "out/downstream-handler/index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_lambda_layer.arn]
  role             = aws_iam_role.circuitbreaker_functions_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("functions/.build/src/out/downstream-handler.zip")
}

resource "aws_lambda_function" "circuitbreaker_healthcheck_function" {
  depends_on       = [aws_cloudwatch_log_group.circuitbreaker_healthcheck_function_loggroup]
  filename         = "functions/.build/src/out/healthcheck-handler.zip"
  function_name    = "circuitbreaker_healthcheck_function_${random_id.stack_id.hex}"
  handler          = "out/healthcheck-handler/index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_lambda_layer.arn]
  role             = aws_iam_role.circuitbreaker_functions_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("functions/.build/src/out/healthcheck-handler.zip")
}

module "circuitbroke_lambda_function" {
  circuitbreakable_service_name = "example_service"
  source                        = "../module"
  stack_id                      = random_id.stack_id.hex
  downstream_lambda_function    = aws_lambda_function.circuitbreaker_downstream_function
  healthcheck_lambda_function   = aws_lambda_function.circuitbreaker_healthcheck_function
  circuitbreaker_services_table = aws_dynamodb_table.circuitbreaker_services_table
}
