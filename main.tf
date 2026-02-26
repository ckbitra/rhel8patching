module "vpc" {
  source = "./modules/vpc"

  vpc_cidr    = var.vpc_cidr
  environment = var.environment
  region      = var.region
}

module "ec2" {
  source = "./modules/ec2"

  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.vpc.security_group_id
  environment       = var.environment
  instance_roles    = var.instance_roles

  depends_on = [module.vpc]
}

module "patch_manager" {
  source = "./modules/patch-manager"

  environment                     = var.environment
  s3_bucket_name                  = var.s3_bucket_name
  region                          = var.region
  patch_insights_lambda_s3_bucket = var.patch_insights_lambda_s3_bucket
  patch_insights_lambda_s3_key    = var.patch_insights_lambda_s3_key

  depends_on = [module.ec2]
}

# S3 bucket for SSM / patch / Bedrock logs
resource "aws_s3_bucket" "patch_logs" {
  bucket = "${var.environment}-rhel8-patch-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Environment = var.environment
    Purpose     = "rhel8-patching-logs"
  }
}

# Optional: enable versioning
resource "aws_s3_bucket_versioning" "patch_logs" {
  bucket = aws_s3_bucket.patch_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_lambda_function" "patch_insights" {
  filename         = data.archive_file.lambda_patch_insights.output_path
  source_code_hash = data.archive_file.lambda_patch_insights.output_base64sha256

  function_name = "${var.environment}-patch-insights"
  role          = aws_iam_role.lambda_role.arn # now declared
  handler       = "index.handler"
  runtime       = "python3.9"

  environment {
    variables = {
      LOG_BUCKET = aws_s3_bucket.patch_logs.id # now declared
    }
  }

  depends_on = [data.archive_file.lambda_patch_insights]
}


# INLINE ZIP CREATION
data "archive_file" "lambda_patch_insights" {
  type        = "zip"
  output_path = "lambda-patch-insights.zip"

  source {
    content  = <<-EOT
      import json
      import boto3
      
      def handler(event, context):
          ssm = boto3.client('ssm')
          # Placeholder for Bedrock analysis
          return {
              "statusCode": 200, 
              "body": json.dumps({
                  "message": "RHEL8 patch analysis ready",
                  "event": event
              })
          }
    EOT
    filename = "index.py"
  }
}

/*
resource "aws_lambda_function" "patch_insights" {
  filename         = "lambda-patch-insights.zip"  # Create this file first
  function_name    = "${var.environment}-patch-insights"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("lambda-patch-insights.zip")
  
  environment {
    variables = {
      LOG_BUCKET = aws_s3_bucket.patch_logs.id
    }
  }
}
*/

/*
resource "aws_lambda_function" "patch_insights" {
  function_name = "${var.environment}-patch-insights"
  s3_bucket     = var.patch_insights_lambda_s3_bucket
  s3_key        = var.patch_insights_lambda_s3_key
  handler       = var.patch_insights_lambda_handler
  runtime       = var.patch_insights_lambda_runtime
  role          = aws_iam_role.patch_insights_lambda_role.arn

  environment {
    variables = {
      BEDROCK_MODEL = "anthropic.claude-3-5-sonnet-20240620-v1:0"
      S3_LOG_BUCKET = var.s3_bucket_name
      REGION        = var.region
      # any other config your code needs
    }
  }
}

resource "aws_cloudwatch_event_rule" "patch_failure" {
  name          = "${var.environment}-patch-failure-rule"
  description   = "Trigger patch‑insights lambda when a maintenance window execution fails"
  event_pattern = jsonencode(var.patch_insights_event_pattern)
}
*/

resource "aws_cloudwatch_event_rule" "patch_failure" {
  name        = "${var.environment}-patch-failure-rule"
  description = "Catch SSM Patch Manager failures"

  event_pattern = jsonencode({
    source      = ["aws.ssm"]
    detail-type = ["Patch Manager Compliance State Change"]
    detail = {
      status = ["NonCompliant", "Failed"]
    }
  })
}

resource "aws_cloudwatch_event_target" "invoke_patch_insights" {
  rule      = aws_cloudwatch_event_rule.patch_failure.name
  target_id = "PatchInsightsLambda"
  arn       = aws_lambda_function.patch_insights.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.patch_insights.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.patch_failure.arn
}

