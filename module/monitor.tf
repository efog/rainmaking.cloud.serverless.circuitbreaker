resource "aws_sns_topic" "circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic" {
  name = "${var.circuitbreakable_service_name}circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic_${var.stack_id}"
}

resource "aws_cloudwatch_metric_alarm" "circuitbreaker_healthcheck_invocation_monitoring_alarm" {
  alarm_name                = "AWS/Lambda Errors FunctionName=${var.healthcheck_lambda_function.function_name}"
  alarm_description         = "This alarm detects healthy healthchecks."
  actions_enabled           = true
  ok_actions                = ["${aws_sns_topic.circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic.arn}"]
  metric_name               = "Errors"
  namespace                 = "AWS/Lambda"
  statistic                 = "Sum"
  period                    = 60
  dimensions = {
    FunctionName = var.healthcheck_lambda_function.function_name
  }
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "circuitbreaker_downstream_invocation_monitoring_alarm" {
  alarm_name                = "AWS/Lambda Errors FunctionName=${var.downstream_lambda_function.function_name}"
  alarm_description         = "This alarm detects high error counts. Errors includes the exceptions thrown by the code as well as exceptions thrown by the Lambda runtime. You can check the logs related to the function to diagnose the issue."
  actions_enabled           = true
  alarm_actions             = ["${aws_sns_topic.circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic.arn}"]
  metric_name               = "Errors"
  namespace                 = "AWS/Lambda"
  statistic                 = "Sum"
  period                    = 60
  dimensions = {
    FunctionName = var.downstream_lambda_function.function_name
  }
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

data "aws_iam_policy_document" "circuitbreaker_circuitalarm_invocation_lambda_topic_subscription_policy_document" {
  statement {
    actions = ["sns:Publish"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    resources = [aws_sns_topic.circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic.arn]
    # condition {
    #   test     = "ArnLike"
    #   variable = "SourceArn"
    #   values   = ["arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:*"]
    # }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic_policy" {
  arn    = aws_sns_topic.circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic.arn
  policy = data.aws_iam_policy_document.circuitbreaker_circuitalarm_invocation_lambda_topic_subscription_policy_document.json
}

resource "aws_sns_topic_subscription" "circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic_sub" {
  topic_arn            = aws_sns_topic.circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic.arn
  protocol             = "lambda"
  endpoint             = aws_lambda_function.circuitbreaker_circuitalarm_function.arn
  raw_message_delivery = false
}

resource "aws_lambda_permission" "circuitbreaker_circuitalarm_invocation_event_lambda_permissions" {
  statement_id  = "allow_sns_circuitbreaker_circuitalarm_invocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.circuitbreaker_circuitalarm_function.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic.arn
}
