# data "aws_iam_policy_document" "circuitbreaker_functions_healthcheck_policy_document" {
#   statement {
#     effect = "Allow"
#     actions = [ "lambda:invokeFunction" ]
#     resources = [ var.healthcheck_lambda_function.arn ]
#     principals {
#       type        = "Service"
#       identifiers = ["sns.amazonaws.com"]
#     }
#     condition {
#       test     = "ArnLike"
#       variable = "SourceArn"
#       values   = ["arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
#     }
#     condition {
#       test = "StringEquals"
#       variable = "aws:SourceAccount"
#       values = [ data.aws_caller_identity.current.account_id ]
#     }
#   }
# }
