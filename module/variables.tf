variable "circuitbreakable_service_name" {
  default     = "a_service"
  description = "The name of the circuit breakable service"
  type        = string
}

variable "stack_id" {
  description = "unique stack identifier"
  type        = string
}

variable "downstream_lambda_function" {
  description = "downstream function Terraform instanciation"
}

variable "healthcheck_lambda_function" {
  description = "healthcheck function Terraform instanciation"
}

variable "circuitbreaker_services_table" {
  description = "circuitbreaker services dynamodb table Terraform instanciation"
}

variable "healthcheck_schedule_expression" {
  type        = string
  default     = "rate(1 minute)"
  description = "healthcheck scheduling expression"
}

variable "downstream_monitoring_configuration" {
  description = "Cloudwatch alarm configuration for the Downstream Function"
  type = object({
    actions_enabled     = bool
    comparison_operator = string
    dimensions = object({
      FunctionName = string
      Version      = string
    })
    evaluation_periods  = number
    datapoints_to_alarm = number
    metric_name         = string
    period              = number
    statistic           = string
    treat_missing_data  = string
    threshold           = number
  })
  default = {
    actions_enabled     = true
    comparison_operator = "GreaterThanThreshold"
    datapoints_to_alarm = 3
    dimensions = {
      FunctionName = ""
      Version      = ""
    }
    evaluation_periods = 3
    metric_name        = "Errors"
    period             = 60
    statistic          = "Sum"
    threshold          = 1
    treat_missing_data = "notBreaching"
  }
}

variable "healthcheck_monitoring_configuration" {
  description = "Cloudwatch alarm configuration for the Healthcheck Function"
  type = object({
    actions_enabled     = bool
    comparison_operator = string
    dimensions = object({
      FunctionName = string
      Version      = string
    })
    evaluation_periods  = number
    datapoints_to_alarm = number
    metric_name         = string
    period              = number
    statistic           = string
    treat_missing_data  = string
    threshold           = number
  })
  default = {
    actions_enabled     = true
    comparison_operator = "GreaterThanOrEqualToThreshold"
    datapoints_to_alarm = 1
    dimensions = {
      FunctionName = ""
      Version      = ""
    }
    evaluation_periods = 1
    metric_name        = "Errors"
    period             = 60
    statistic          = "Sum"
    threshold          = 1
    treat_missing_data = "notBreaching"
  }
}
