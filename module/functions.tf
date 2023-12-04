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

data "aws_iam_policy_document" "circuitbreaker_circuitalarm_function_policy" {
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

data "aws_iam_policy_document" "circuitbreaker_upstream_function_policy" {
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
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "circuitbreaker_circuitalarm_function_policy" {
  policy = data.aws_iam_policy_document.circuitbreaker_circuitalarm_function_policy.json
  name   = "circuitbreaker_circuitalarm_function_policy_${var.stack_id}"
}

resource "aws_iam_policy" "circuitbreaker_upstream_function_policy" {
  policy = data.aws_iam_policy_document.circuitbreaker_upstream_function_policy.json
  name   = "circuitbreaker_upstream_function_policy_${var.stack_id}"
}

resource "aws_iam_role" "circuitbreaker_upstream_function_role" {
  name               = "circuitbreaker_upstream_function_role_${var.stack_id}"
  assume_role_policy = data.aws_iam_policy_document.circuitbreaker_sfn_statemachine_functions_assumerole_policy.json
}

resource "aws_iam_role" "circuitbreaker_circuitalarm_function_role" {
  name               = "circuitbreaker_circuitalarm_function_role_${var.stack_id}"
  assume_role_policy = data.aws_iam_policy_document.circuitbreaker_sfn_statemachine_functions_assumerole_policy.json
}

resource "aws_iam_policy_attachment" "circuitbreaker_upstream_attachments" {
  lifecycle {
    ignore_changes = [policy_arn]
  }
  name       = "circuitbreaker_upstream_attachment"
  policy_arn = aws_iam_policy.circuitbreaker_upstream_function_policy.arn
  roles      = [aws_iam_role.circuitbreaker_upstream_function_role.name]
}

resource "aws_iam_policy_attachment" "circuitbreaker_circuitalarm_attachments" {
  lifecycle {
    ignore_changes = [policy_arn]
  }
  name       = "circuitbreaker_circuitalarm_attachment"
  policy_arn = aws_iam_policy.circuitbreaker_circuitalarm_function_policy.arn
  roles      = [aws_iam_role.circuitbreaker_circuitalarm_function_role.name]
}

resource "aws_cloudwatch_log_group" "circuitbreaker_upstream_function_loggroup" {
  name              = "/aws/lambda/upstream_function_${var.stack_id}"
  retention_in_days = 1
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_log_group" "circuitbreaker_circuitalarm_function_loggroup" {
  name              = "/aws/lambda/circuitalarm_function_${var.stack_id}"
  retention_in_days = 1
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_lambda_layer_version" "circuitbreaker_sfn_statemachine_functions_layer" {
  filename            = "${path.module}/functions/.build/src/out/node_package.zip"
  layer_name          = "circuitbreaker_sfn_statemachine_functions_layer_${var.stack_id}"
  compatible_runtimes = ["nodejs18.x"]
  source_code_hash    = filebase64sha256("${path.module}/functions/.build/src/out/node_package.zip")
}

resource "aws_lambda_function" "circuitbreaker_upstream_statemachine_function" {
  filename         = "${path.module}/functions/.build/src/out/upstream-handler.zip"
  function_name    = "upstream_function_${var.stack_id}"
  handler          = "out/upstream-handler/index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_sfn_statemachine_functions_layer.arn]
  role             = aws_iam_role.circuitbreaker_upstream_function_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("${path.module}/functions/.build/src/out/upstream-handler.zip")
  environment {
    variables = {
      "LAMBDA_UPSTREAM_SERVICENAME" = var.circuitbreakable_service_name
      "LAMBDA_UPSTREAM_SERVICESTABLENAME" = var.circuitbreaker_services_table.name
    }
  }
}

resource "aws_lambda_function" "circuitbreaker_circuitalarm_function" {
  filename         = "${path.module}/functions/.build/src/out/circuitalarm-handler.zip"
  function_name    = "circuitalarm_function_${var.stack_id}"
  handler          = "out/circuitalarm-handler/index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_sfn_statemachine_functions_layer.arn]
  role             = aws_iam_role.circuitbreaker_circuitalarm_function_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("${path.module}/functions/.build/src/out/circuitalarm-handler.zip")
  environment {
    variables = {
      "LAMBDA_UPSTREAM_SERVICENAME" = var.circuitbreakable_service_name
      "LAMBDA_UPSTREAM_SERVICESTABLENAME" = var.circuitbreaker_services_table.name
    }
  }
}
