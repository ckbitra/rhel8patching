resource "random_id" "suffix" {
  byte_length = 4
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "patch_insights_lambda_role" {
  name               = "${var.environment}-patch-insights-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "patch_insights_logs" {
  role       = aws_iam_role.patch_insights_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM role for the patch_insights Lambda
resource "aws_iam_role" "lambda_role" {
  #name = "${var.environment}-patch-insights-lambda-role"
  name = "${var.environment}-patch-insights-lambda-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Basic permissions for Lambda to write logs and read S3 logs bucket
resource "aws_iam_role_policy_attachment" "lambda_basic_logging" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


/* add any other inline policies or attachments your lambda needs */