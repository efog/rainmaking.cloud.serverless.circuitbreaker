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

data "aws_iam_policy_document" "circuitbreaker_functions_dynamodb_rw_policy" {
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
}

resource "aws_iam_policy" "circuitbreaker_functions_dynamodb_rw_policy" {
  policy = data.aws_iam_policy_document.circuitbreaker_functions_dynamodb_rw_policy.json
  name   = "circuitbreaker_functions_dynamodb_rw_policy_${var.stack_id}"
}

resource "aws_iam_role" "circuitbreaker_sfn_statemachine_functions_role" {
  name               = "circuitbreaker_statemachine_functions_role_${var.stack_id}"
  assume_role_policy = data.aws_iam_policy_document.circuitbreaker_sfn_statemachine_functions_assumerole_policy.json
}

resource "aws_iam_policy_attachment" "circuitbreaker_sfn_statemachine_functions_attachments" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    aws_iam_policy.circuitbreaker_functions_dynamodb_rw_policy.arn,
  ])
  name       = "circuitbreaker_sfn_statemachine_functions_attachments_${each.key}"
  policy_arn = each.value
  roles      = [aws_iam_role.circuitbreaker_sfn_statemachine_functions_role.name]
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
  role             = aws_iam_role.circuitbreaker_sfn_statemachine_functions_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("${path.module}/functions/.build/src/out/upstream-handler.zip")
  environment {
    variables = {
      "LAMBDA_UPSTREAM_SERVICESTABLENAME" = var.circuitbreaker_services_table.name
    }
  }
}

resource "aws_lambda_function" "circuitbreaker_circuitalarm_statemachine_function" {
  filename         = "${path.module}/functions/.build/src/out/circuitalarm-handler.zip"
  function_name    = "circuitalarm_function_${var.stack_id}"
  handler          = "out/circuitalarm-handler/index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_sfn_statemachine_functions_layer.arn]
  role             = aws_iam_role.circuitbreaker_sfn_statemachine_functions_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("${path.module}/functions/.build/src/out/circuitalarm-handler.zip")
}