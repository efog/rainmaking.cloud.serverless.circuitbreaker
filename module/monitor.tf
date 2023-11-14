resource "aws_sns_topic" "healthcheck_scheduled_invocation_monitoring_alarm_topic" {
  name = "${var.circuitbreakable_service_name}healthcheck_scheduled_invocation_monitoring_alarm_topic_${var.stack_id}"
}

resource "aws_cloudwatch_metric_alarm" "healthcheck_scheduled_invocation_monitoring_alarm" {
  actions_enabled     = true
  alarm_actions       = ["${aws_sns_topic.healthcheck_scheduled_invocation_monitoring_alarm_topic.arn}"]
  alarm_description   = "This alarm monitors healthcheck function"
  alarm_name          = "${var.circuitbreakable_service_name}_healthcheck_scheduled_invocation_monitoring_alarm_${var.stack_id}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    "FunctionName" = var.healthcheck_lambda_function.function_name
  }
  evaluation_periods        = 1
  insufficient_data_actions = []
  metric_name               = "Errors"
  namespace                 = "AWS/LAMBDA"
  ok_actions                = ["${aws_sns_topic.healthcheck_scheduled_invocation_monitoring_alarm_topic.arn}"]
  period                    = 60
  statistic                 = "Minimum"
  threshold                 = 2
  treat_missing_data        = "notBreaching"
}
