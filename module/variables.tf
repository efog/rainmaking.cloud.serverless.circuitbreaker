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
  type    = string
  default = "rate(1 minute)"
  description = "healthcheck scheduling expression"
}
