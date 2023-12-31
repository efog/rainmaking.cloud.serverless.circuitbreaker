#######
# Template file containing the necessary resource to monitory Downstream and Healthcheck functions provided as inputs.
#######

resource "aws_sns_topic" "circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic" {
  name = "${var.circuitbreakable_service_name}circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic_${var.stack_id}"
}

##
# Cloudwatch alarm monitoring the healthcheck Lambda Function
##
resource "aws_cloudwatch_metric_alarm" "circuitbreaker_healthcheck_invocation_monitoring_alarm" {
  alarm_name        = "AWS/Lambda Errors FunctionName=${var.healthcheck_lambda_function.function_name}"
  alarm_description = "This alarm detects healthy healthchecks."
  actions_enabled   = var.healthcheck_monitoring_configuration.actions_enabled
  alarm_actions     = ["${aws_sns_topic.circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic.arn}"]
  ok_actions        = ["${aws_sns_topic.circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic.arn}"]
  metric_name       = var.healthcheck_monitoring_configuration.metric_name
  namespace         = "AWS/Lambda"
  statistic         = var.healthcheck_monitoring_configuration.statistic
  period            = var.healthcheck_monitoring_configuration.period
  dimensions = {
    # Resource = "${var.healthcheck_lambda_function.arn}:${var.healthcheck_lambda_function.version}"
    FunctionName = var.healthcheck_monitoring_configuration.dimensions.FunctionName
    # ExecutedVersion      = var.healthcheck_monitoring_configuration.dimensions.Version
  }
  evaluation_periods  = var.healthcheck_monitoring_configuration.evaluation_periods
  datapoints_to_alarm = var.healthcheck_monitoring_configuration.datapoints_to_alarm
  threshold           = var.healthcheck_monitoring_configuration.threshold
  comparison_operator = var.healthcheck_monitoring_configuration.comparison_operator
  treat_missing_data  = var.healthcheck_monitoring_configuration.treat_missing_data
}

##
# Cloudwatch alarm monitoring the downstream Lambda Function
##
resource "aws_cloudwatch_metric_alarm" "circuitbreaker_downstream_invocation_monitoring_alarm" {
  alarm_name        = "AWS/Lambda Errors FunctionName=${var.downstream_lambda_function.function_name}"
  alarm_description = "This alarm detects high error counts. Errors includes the exceptions thrown by the code as well as exceptions thrown by the Lambda runtime. You can check the logs related to the function to diagnose the issue."
  actions_enabled   = var.downstream_monitoring_configuration.actions_enabled
  alarm_actions     = ["${aws_sns_topic.circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic.arn}"]
  metric_name       = var.downstream_monitoring_configuration.metric_name
  namespace         = "AWS/Lambda"
  statistic         = var.downstream_monitoring_configuration.statistic
  period            = var.downstream_monitoring_configuration.period
  dimensions = {
    FunctionName = var.downstream_monitoring_configuration.dimensions.FunctionName
    # Version      = var.downstream_monitoring_configuration.dimensions.Version
  }
  evaluation_periods  = var.downstream_monitoring_configuration.evaluation_periods
  datapoints_to_alarm = var.downstream_monitoring_configuration.datapoints_to_alarm
  threshold           = var.downstream_monitoring_configuration.threshold
  comparison_operator = var.downstream_monitoring_configuration.comparison_operator
  treat_missing_data  = var.downstream_monitoring_configuration.treat_missing_data
}

##
# IAM permissions statements granting cloudwatch the capability to publish onto monitoring SNS topic.
##
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

##
# SNS Topic policy granting permissions to CLoudWatch Alarms
##
resource "aws_sns_topic_policy" "circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic_policy" {
  arn    = aws_sns_topic.circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic.arn
  policy = data.aws_iam_policy_document.circuitbreaker_circuitalarm_invocation_lambda_topic_subscription_policy_document.json
}

##
# AWS SNS Topic alarm handler Lambda Function subscription
##
resource "aws_sns_topic_subscription" "circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic_sub" {
  topic_arn            = aws_sns_topic.circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic.arn
  protocol             = "lambda"
  endpoint             = aws_lambda_function.circuitbreaker_alarmhandler_function.arn
  raw_message_delivery = false
}

##
# Lambda Permissions granting InvokeFunction to SNS topic.
##
resource "aws_lambda_permission" "circuitbreaker_circuitalarm_invocation_event_lambda_permissions" {
  statement_id  = "allow_sns_circuitbreaker_circuitalarm_invocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.circuitbreaker_alarmhandler_function.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.circuitbreaker_circuitalarm_invocation_monitoring_alarm_topic.arn
}
