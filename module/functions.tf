#######
# This terraform template defines the circuit-breaker module supporting lambda functions
#######

##
# Circuit-breaker lambda functions assume role permission statements
##
data "aws_iam_policy_document" "circuitbreaker_sfn_statemachine_functions_assumerole_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

##
# Circuit-breaker functions role permission policy statements
##
data "aws_iam_policy_document" "circuitbreaker_functions_policy" {
  statement {
    sid    = "dynamodbRW"
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
      "dynamodb:GetRecords"
    ]
    resources = [var.circuitbreaker_services_table.arn]
  }
  statement {
    effect = "Allow"
    actions = ["logs:CreateLogGroup",
      "logs:CreateLogStream",
    "logs:PutLogEvents"]
    resources = ["*"]
  }
}

##
# Circuit-breaker functions IAM Policy
##
resource "aws_iam_policy" "circuitbreaker_functions_policy" {
  policy = data.aws_iam_policy_document.circuitbreaker_functions_policy.json
  name   = "circuitbreaker_functions_policy_${var.stack_id}"
}

##
# Circuit-breaker functions IAM Role
##
resource "aws_iam_role" "circuitbreaker_functions_role" {
  name               = "circuitbreaker_functions_role_${var.stack_id}"
  assume_role_policy = data.aws_iam_policy_document.circuitbreaker_sfn_statemachine_functions_assumerole_policy.json
}

##
# Circuit-breaker functions IAM Role policy attachment
##
resource "aws_iam_policy_attachment" "circuitbreaker_circuitalarm_attachments" {
  lifecycle {
    ignore_changes = [policy_arn]
  }
  depends_on = [ aws_iam_policy.circuitbreaker_functions_policy, aws_iam_role.circuitbreaker_functions_role ]
  name       = "circuitbreaker_circuitalarm_attachment"
  policy_arn = aws_iam_policy.circuitbreaker_functions_policy.arn
  roles      = [aws_iam_role.circuitbreaker_functions_role.name]
}

##
# Circuit-breaker functions shared Lambda Function Layer
##
resource "aws_lambda_layer_version" "circuitbreaker_sfn_statemachine_functions_layer" {
  filename            = "${path.module}/functions/.build/src/out/node_package.zip"
  layer_name          = "circuitbreaker_sfn_statemachine_functions_layer_${var.stack_id}"
  compatible_runtimes = ["nodejs18.x"]
  source_code_hash    = filebase64sha256("${path.module}/functions/.build/src/out/node_package.zip")
}

##
# Circuit-breaker upstream Lambda Function. The upstream function is the state machine's entry point
##
resource "aws_lambda_function" "circuitbreaker_upstream_statemachine_function" {
  filename         = "${path.module}/functions/.build/src/out/upstream-handler.zip"
  function_name    = "upstream_function_${var.stack_id}"
  handler          = "out/upstream-handler/index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_sfn_statemachine_functions_layer.arn]
  role             = aws_iam_role.circuitbreaker_functions_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("${path.module}/functions/.build/src/out/upstream-handler.zip")
  environment {
    variables = {
      "LAMBDA_UPSTREAM_SERVICENAME" = var.circuitbreakable_service_name
      "LAMBDA_UPSTREAM_SERVICESTABLENAME" = var.circuitbreaker_services_table.name
    }
  }
}

##
# Circuit-breaker alarm handler Lambda Function. This function handles alarms raised by Cloudwatch and dispatched through SNS.
##
resource "aws_lambda_function" "circuitbreaker_alarmhandler_function" {
  filename         = "${path.module}/functions/.build/src/out/circuitalarm-handler.zip"
  function_name    = "circuitalarm_function_${var.stack_id}"
  handler          = "out/circuitalarm-handler/index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_sfn_statemachine_functions_layer.arn]
  role             = aws_iam_role.circuitbreaker_functions_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("${path.module}/functions/.build/src/out/circuitalarm-handler.zip")
  environment {
    variables = {
      "LAMBDA_UPSTREAM_SERVICENAME" = var.circuitbreakable_service_name
      "LAMBDA_UPSTREAM_SERVICESTABLENAME" = var.circuitbreaker_services_table.name
    }
  }
}
