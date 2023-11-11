variable "circuitbreakable_service_name" {
  default = "a_service"
  type    = string
}

variable "downstream_lambda_function" {
  type = object(
    {
      arn = string
    }
  )
}

variable "healthcheck_lambda_function" {
  type = object(
    {
      arn = string
    }
  )
}
