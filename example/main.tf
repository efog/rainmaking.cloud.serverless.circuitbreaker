resource "aws_lambda_layer_version" "circuitbreaker_lambda_layer" {
  filename            = "functions/.build/src/out/node_package.zip"
  layer_name          = "circuitbreaker_lambda_layer"
  compatible_runtimes = ["nodejs18.x"]
  source_code_hash    = filebase64sha256("functions/.build/src/out/node_package.zip")
}

data "aws_iam_policy_document" "circuitbreaker_functions_assumerole_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "circuitbreaker_functions_role" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.circuitbreaker_functions_assumerole_policy.json
}

resource "aws_lambda_function" "circuitbreaker_downstream_function" {
  filename         = "functions/.build/src/out/downstream-handler.zip"
  function_name    = "circuitbreaker_downstream_function"
  handler          = "index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_lambda_layer.arn]
  role             = aws_iam_role.circuitbreaker_functions_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("functions/.build/src/out/downstream-handler.zip")
}

resource "aws_lambda_function" "circuitbreaker_healthcheck_function" {
  filename         = "functions/.build/src/out/healthcheck-handler.zip"
  function_name    = "circuitbreaker_healthcheck_function"
  handler          = "index.handler"
  layers           = [aws_lambda_layer_version.circuitbreaker_lambda_layer.arn]
  role             = aws_iam_role.circuitbreaker_functions_role.arn
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("functions/.build/src/out/healthcheck-handler.zip")
}

module "circuitbroke_lambda_function" {
  source = "../module"
  downstream_lambda_function = aws_lambda_function.circuitbreaker_downstream_function
  healthcheck_lambda_function = aws_lambda_function.circuitbreaker_healthcheck_function
}