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

data "aws_iam_policy_document" "circuitbreaker_sfn_statemachine_lambdainvoke_policy_document" {
  statement {
    effect    = "Allow"
    resources = [
        aws_lambda_function.circuitbreaker_upstream_statemachine_function.arn,
        var.downstream_lambda_function.arn
    ]
    actions = ["lambda:invokeFunction"]
  }
}

resource "aws_iam_policy" "circuitbreaker_sfn_statemachine_lambdainvoke_policy" {
  policy = data.aws_iam_policy_document.circuitbreaker_sfn_statemachine_lambdainvoke_policy_document.json
  name   = "${var.circuitbreakable_service_name}_circuitbreaker_sfn_statemachine_lambdainvoke_policy_${var.stack_id}"
}

resource "aws_iam_role" "circuitbreaker_sfn_statemachine_role" {
  name               = "${var.circuitbreakable_service_name}_role_${var.stack_id}"
  assume_role_policy = data.aws_iam_policy_document.circuitbreaker_sfn_statemachine_assumerole_policy.json
}

resource "aws_iam_policy_attachment" "circuitbreaker_sfn_statemachine_lambdainvoke_policy_attachment" {
  name       = "${var.circuitbreakable_service_name}_circuitbreaker_sfn_statemachine_lambdainvoke_policy_attachment_${var.stack_id}"
  policy_arn = aws_iam_policy.circuitbreaker_sfn_statemachine_lambdainvoke_policy.arn
  roles      = [aws_iam_role.circuitbreaker_sfn_statemachine_role.name]
}

resource "aws_iam_policy" "circuitbreaker_sfn_statemachine_loggroup_policy" {
  policy = data.aws_iam_policy_document.circuitbreaker_sfn_statemachine_logggroup_policy.json
  name   = "${var.circuitbreakable_service_name}_circuitbreaker_sfn_statemachine_loggroup_policy_${var.stack_id}"
}

resource "aws_iam_policy_attachment" "circuitbreaker_sfn_statemachine_loggroup_policy_attachment" {
  name       = "${var.circuitbreakable_service_name}_circuitbreaker_sfn_statemachine_loggroup_policy_attachment_${var.stack_id}"
  policy_arn = aws_iam_policy.circuitbreaker_sfn_statemachine_loggroup_policy.arn
  roles      = [aws_iam_role.circuitbreaker_sfn_statemachine_role.name]
}

resource "aws_sfn_state_machine" "circuitbreaker_sfn_statemachine" {
  depends_on = [aws_cloudwatch_log_group.circuitbreaker_sfn_statemachine_loggroup, aws_iam_role.circuitbreaker_sfn_statemachine_role]
  name       = "${var.circuitbreakable_service_name}_circuitbreaker_statemachine_${var.stack_id}"
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
      "Type": "Task",
      "InputPath": "$",
      "OutputPath": "$",
      "Next": "is circuit closed",
      "Parameters": {"serviceName": "${var.circuitbreakable_service_name}"}, 
      "Resource": "${aws_lambda_function.circuitbreaker_upstream_statemachine_function.arn}",
      "ResultPath": "$.circuitClosedCheck",
      "Catch":[{
        "ErrorEquals": ["States.ALL"],
        "Next": "catch all fallback"
      }]
    },
    "is circuit closed": {
      "Type": "Choice",
      "Default": "downstream function",
      "Choices": [
        {
          "Variable": "$.circuitClosedCheck.body.isCircuitClosed.BOOL",
          "BooleanEquals": false,
          "Next": "fast fail invocation"
        }
      ] 
    },
    "downstream function": {
      "End": true,
      "InputPath": "$",
      "OutputPath": "$",
      "Resource": "${var.downstream_lambda_function.arn}",
      "Type": "Task",
      "Catch":[{
        "ErrorEquals": ["States.ALL"],
        "Next": "catch all fallback"
      }]
    },
    "fast fail invocation": {
      "Type": "Pass",
      "Result": {"statusCode": 503, "body": "service temporarily unavailable."},
      "End": true
    },
    "catch all fallback": {
         "Type": "Pass",
         "Result": {"statusCode": 500, "body": "service failure."},
         "End": true
    }
  }
}
EOF
  role_arn   = aws_iam_role.circuitbreaker_sfn_statemachine_role.arn
  type       = "EXPRESS"
}