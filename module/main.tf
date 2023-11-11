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
  name               = "circuitbreaker_statemachine_functions_role_${var.stack_id}"
  assume_role_policy = data.aws_iam_policy_document.circuitbreaker_sfn_statemachine_functions_assumerole_policy.json
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
  handler          = "index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_sfn_statemachine_functions_layer.arn]
  role             = aws_iam_role.circuitbreaker_sfn_statemachine_functions_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("${path.module}/functions/.build/src/out/upstream-handler.zip")
}

resource "aws_lambda_function" "circuitbreaker_circuitalarm_statemachine_function" {
  filename         = "${path.module}/functions/.build/src/out/circuitalarm-handler.zip"
  function_name    = "circuitalarm_function_${var.stack_id}"
  handler          = "index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_sfn_statemachine_functions_layer.arn]
  role             = aws_iam_role.circuitbreaker_sfn_statemachine_functions_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("${path.module}/functions/.build/src/out/circuitalarm-handler.zip")
}

resource "aws_cloudwatch_log_group" "circuitbreaker_sfn_statemachine_loggroup" {
  name              = "${var.circuitbreakable_service_name}_loggroup_${var.stack_id}"
  retention_in_days = 1
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

data "aws_iam_policy_document" "circuitbreaker_sfn_statemachine_logggroup_policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = ["logs:CreateLogDelivery",
      "logs:CreateLogStream",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutLogEvents",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
    "logs:DescribeLogGroups"]
  }
}

resource "aws_iam_policy" "circuitbreaker_sfn_statemachine_role_policy" {
  policy = data.aws_iam_policy_document.circuitbreaker_sfn_statemachine_logggroup_policy.json
  name   = "${var.circuitbreakable_service_name}_role_policy_${var.stack_id}"
}

resource "aws_iam_role" "circuitbreaker_sfn_statemachine_role" {
  name               = "${var.circuitbreakable_service_name}_role_${var.stack_id}"
  assume_role_policy = data.aws_iam_policy_document.circuitbreaker_sfn_statemachine_assumerole_policy.json
}

resource "aws_iam_policy_attachment" "circuitbreaker_sfn_statemachine_role_policy_attachment" {
  name       = "${var.circuitbreakable_service_name}_role_loggroup_policy_attachment_${var.stack_id}"
  policy_arn = aws_iam_policy.circuitbreaker_sfn_statemachine_role_policy.arn
  roles      = [aws_iam_role.circuitbreaker_sfn_statemachine_role.name]
}

resource "aws_sfn_state_machine" "circuitbreaker_sfn_statemachine" {
  depends_on = [ aws_cloudwatch_log_group.circuitbreaker_sfn_statemachine_loggroup, aws_iam_role.circuitbreaker_sfn_statemachine_role ]
  name = "${var.circuitbreakable_service_name}_circuitbreaker_statemachine_${var.stack_id}"
  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.circuitbreaker_sfn_statemachine_loggroup.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
  definition = <<EOF
{
  "Comment": "A circuit breaker scaffold for ${var.circuitbreakable_service_name}",
  "StartAt": "upstream function",
  "States": {
    "upstream function": {
      "InputPath": "$",
      "OutputPath": "$",
      "Next": "is circuit closed",
      "Parameters": {"$.serviceName": "${var.circuitbreakable_service_name}"}, 
      "Resource": "${aws_lambda_function.circuitbreaker_upstream_statemachine_function.arn}",
      "ResultPath": "$.isCircuitClosed",
      "Type": "Task"
    },
    "is circuit closed": {
      "Type": "Choice",
      "Default": "downstream function",
      "Choices": [
        {
          "Variable": "$.isCircuitClosed",
          "BooleanEquals": false,
          "Next": "fail invocation"
        }
      ] 
    },
    "downstream function": {
      "End": true,
      "InputPath": "$",
      "OutputPath": "$",
      "Resource": "${var.downstream_lambda_function.arn}",
      "Type": "Task"
    },
    "fail invocation": {
      "Type": "Pass",
      "Result": {"statusCode": 503, "body": "service temporarily unavailable."},
      "End": true
    }
  }
}
EOF
  role_arn   = aws_iam_role.circuitbreaker_sfn_statemachine_role.arn
  type       = "EXPRESS"
}
