variable "circuitbreakable_service_name" {
  default = "a_service"
  type    = string
}

variable "stack_id" {
  type = string

}

variable "downstream_lambda_function" {
  type = object(
    {
      arn = string
    }
  )
}

variable "healthcheck_lambda_function" {
}

variable "circuitbreaker_services_table" {
}

variable "healthcheck_schedule_expression" {
  type    = string
  default = "rate(2 minutes)"
}
