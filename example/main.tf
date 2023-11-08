resource "aws_lambda_layer_version" "circuitbreaker_lambda_layer" {
  filename   = "functions/.build/out/node_package.zip"
  layer_name = "circuitbreaker_lambda_layer"
  compatible_runtimes = ["nodejs18.x"]
  source_code_hash = filebase64sha256("functions/.build/out/node_package.zip")
}