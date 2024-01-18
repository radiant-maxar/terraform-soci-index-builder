data "aws_availability_zones" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_partition  = data.aws_partition.current.partition
  aws_region     = data.aws_region.current.name
}

module "soci_repository_name_parsing_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 6.5.0"

  create_package         = false
  create_role            = true
  function_name          = "soci-repository-name-parsing-lambda"
  description            = "ECR repository name parsing lamdba to support SOCI indexing."
  handler                = "index.handler"
  runtime                = "python3.12"
  local_existing_package = "${path.module}/soci_repository_name_parsing.zip"

  cloudwatch_logs_retention_in_days = 30
  environment_variables = {
    AWS_ACCOUNT_ID = local.aws_account_id
    AWS_PARTITION  = local.aws_partition
  }

  tags = var.tags
}

resource "aws_lambda_invocation" "soci_repository_name_parsing" {
  function_name   = module.soci_repository_name_parsing_lambda.lambda_function_arn
  input           = jsonencode({ filters = var.image_tag_filters })
  lifecycle_scope = "CRUD"
}

data "aws_iam_policy_document" "soci_index_generator_lambda" {
  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:CompleteLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
    ]
    resources = jsondecode(aws_lambda_invocation.soci_repository_name_parsing.result)["repository_arns"]
  }

  statement {
    sid = "AllowECRGetAuthorizationToken"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = [
      "*"
    ]
  }
}

module "soci_index_generator_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 6.5.0"

  attach_policy_json                = true
  cloudwatch_logs_retention_in_days = 90
  create_package                    = false
  create_role                       = true
  description                       = "Given an Amazon ECR container repository and image, Lambda generates image SOCI artifacts and pushes to repository."
  ephemeral_storage_size            = 10240
  function_name                     = "soci-index-generator-lambda"
  memory_size                       = 2536
  policy_json                       = data.aws_iam_policy_document.soci_index_generator_lambda.json
  handler                           = "main"
  runtime                           = "provided.al2"
  timeout                           = 900

  s3_existing_package = {
    bucket = var.s3_bucket_name
    key    = "${var.s3_key_prefix}functions/packages/soci-index-generator-lambda/soci_index_generator_lambda.zip"
  }

  tags = var.tags
}

data "aws_iam_policy_document" "ecr_image_action_event_filtering_lambda" {
  statement {
    actions = [
      "lambda:InvokeFunction",
      "lambda:InvokeAsync",
    ]
    resources = [
      module.soci_index_generator_lambda.lambda_function_arn
    ]
  }
}

module "ecr_image_action_event_filtering_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 6.5.0"

  create_package = false
  create_role    = true
  description    = "Given an Amazon ECR image action event from EventBridge, matches event detail.repository-name and detail.image-tag against one or more known patterns and invokes Executor Lambda with the same event on a match."
  function_name  = "soci-ecr-image-action-event-filtering-lambda"
  handler        = "ecr_image_action_event_filtering_lambda_function.lambda_handler"
  runtime        = "python3.9"
  timeout        = 300

  attach_policy_json                = true
  cloudwatch_logs_retention_in_days = 90
  policy_json                       = data.aws_iam_policy_document.ecr_image_action_event_filtering_lambda.json

  environment_variables = {
    soci_repository_image_tag_filters = join(",", var.image_tag_filters)
    soci_index_generator_lambda_arn   = module.soci_index_generator_lambda.lambda_function_arn
  }

  s3_existing_package = {
    bucket = var.s3_bucket_name
    key    = "${var.s3_key_prefix}functions/packages/ecr-image-action-event-filtering/lambda.zip"
  }

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "ecr_image_action_event_bridge_rule" {
  name        = "soci-ecr-image-action-event-bridge-rule"
  description = "Invokes Amazon ECR image action event filtering Lambda function when image is successfully pushed to ECR."
  state       = "ENABLED"

  event_pattern = jsonencode({
    "detail-type" = ["ECR Image Action"]
    detail = {
      "action-type" = ["PUSH"]
      result        = ["SUCCESS"]
    }
    region = [local.aws_region]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "ecr_image_action_event_bridge_target" {
  rule      = aws_cloudwatch_event_rule.ecr_image_action_event_bridge_rule.name
  target_id = "ecr-image-action-lambda-target"
  arn       = module.ecr_image_action_event_filtering_lambda.lambda_function_arn
}

resource "aws_lambda_permission" "ecr_image_action_event_filtering_lambda_invoke_permission" {
  action        = "lambda:InvokeFunction"
  function_name = module.ecr_image_action_event_filtering_lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecr_image_action_event_bridge_rule.arn
}
