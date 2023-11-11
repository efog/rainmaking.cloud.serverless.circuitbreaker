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

resource "aws_iam_role" "circuitbreaker_sfn_statemachine_functions_role" {
  name               = "circuitbreaker_statemachine_functions_role"
  assume_role_policy = data.aws_iam_policy_document.circuitbreaker_sfn_statemachine_functions_assumerole_policy.json
}

resource "aws_lambda_layer_version" "circuitbreaker_sfn_statemachine_functions_layer" {
  filename            = "${path.module}/functions/.build/src/out/node_package.zip"
  layer_name          = "circuitbreaker_sfn_statemachine_functions_layer"
  compatible_runtimes = ["nodejs18.x"]
  source_code_hash    = filebase64sha256("${path.module}/functions/.build/src/out/node_package.zip")
}

resource "aws_lambda_function" "circuitbreaker_upstream_statemachine_function" {
  filename         = "${path.module}/functions/.build/src/out/upstream-handler.zip"
  function_name    = "circuitbreaker_upstream_statemachine_function"
  handler          = "index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_sfn_statemachine_functions_layer.arn]
  role             = aws_iam_role.circuitbreaker_sfn_statemachine_functions_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("${path.module}/functions/.build/src/out/upstream-handler.zip")
}

resource "aws_lambda_function" "circuitbreaker_circuitalarm_statemachine_function" {
  filename         = "${path.module}/functions/.build/src/out/circuitalarm-handler.zip"
  function_name    = "circuitbreaker_circuitalarm_statemachine_function"
  handler          = "index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_sfn_statemachine_functions_layer.arn]
  role             = aws_iam_role.circuitbreaker_sfn_statemachine_functions_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("${path.module}/functions/.build/src/out/circuitalarm-handler.zip")
}

data "aws_iam_policy_document" "circuitbreaker_sfn_statemachine_assumerole_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "circuitbreaker_sfn_statemachine_role" {
  name               = "${var.circuitbreakable_service_name}_role"
  assume_role_policy = data.aws_iam_policy_document.circuitbreaker_sfn_statemachine_assumerole_policy.json
}

resource "aws_sfn_state_machine" "circuitbreaker_sfn_statemachine" {
  name       = "${var.circuitbreakable_service_name}_circuitbreaker_statemachine"
  definition = <<EOF
{
  "comment": "A circuit breaker scaffold for ${var.circuitbreakable_service_name}",
  "startAt": "upstream function",
  "states": {
    "upstream function": {
      "inputPath": "$",
      "outputPath": "$",
      "next": "is circuit closed",
      "parameters": {"serviceName.$": "${var.circuitbreakable_service_name}"}, 
      "resource": "${aws_lambda_function.circuitbreaker_upstream_statemachine_function.arn}",
      "resultPath": "$.isCircuitClosed",
      "type": "task"
    },
    "is circuit closed": {
      "type": "choice",
      "default": "fail invocation"
      "choices": [
        {
          "variable": "$.isCircuitClosed",
          "booleanEquals": true,
          "next": "downstream function"
        }
      ] 
    },
    "downstream function": {
      "end": true,
      "inputPath": "$",
      "outputPath": "$",
      "resource": "${var.downstream_lambda_function.arn}",
      "type": "task"
    }
  }
}
EOF
  role_arn   = aws_iam_role.circuitbreaker_sfn_statemachine_role.arn
  type       = "EXPRESS"
}
