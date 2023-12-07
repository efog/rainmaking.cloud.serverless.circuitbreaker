#######
# The resources defined here-in are responsible of triggering the scheduled based healthchecks
#######

##
# Assume role policy document for Events service (EventBridge)
##
data "aws_iam_policy_document" "healthcheck_scheduled_invocation_event_target_role_assume_policy_document" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

##
# IAM Role assumed by EventBridge
##
resource "aws_iam_role" "healthcheck_scheduled_invocation_event_target_role" {
  name               = substr("healthcheck_scheduled_invocation_event_target_role_${var.stack_id}", 0, 64)
  assume_role_policy = data.aws_iam_policy_document.healthcheck_scheduled_invocation_event_target_role_assume_policy_document.json
}

##
# EventBridge scheduled trigger event rule
##
resource "aws_cloudwatch_event_rule" "healthcheck_scheduled_invocation_event_rule" {
  name                = substr("${var.circuitbreakable_service_name}_healthcheck_scheduled_invocation_${var.stack_id}", 0, 64)
  description         = "${var.circuitbreakable_service_name} on stack ${var.stack_id} scheduled event"
  schedule_expression = var.healthcheck_schedule_expression
}


##
# Permissions granted by Lambda Function to EventBridge
##
resource "aws_lambda_permission" "healthcheck_scheduled_invocation_event_lambda_permissions" {
  statement_id  = "allow_healthcheck_scheduled_invocation"
  action        = "lambda:InvokeFunction"
  function_name = var.healthcheck_lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.healthcheck_scheduled_invocation_event_rule.arn
}

##
# EventBridge scheduled event target.
##
resource "aws_cloudwatch_event_target" "healthcheck_scheduled_invocation_event_target" {
  rule = aws_cloudwatch_event_rule.healthcheck_scheduled_invocation_event_rule.name
  arn  = var.healthcheck_lambda_function.arn
}

