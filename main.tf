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
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 60

  environment {
    variables = {
      LOG_BUCKET    = aws_s3_bucket.patch_logs.id
      BEDROCK_MODEL = "anthropic.claude-3-5-sonnet-20240620-v1:0"
      REGION        = var.region
      ENVIRONMENT   = var.environment
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
import os
import boto3
from datetime import datetime, timezone

BEDROCK_MODEL = os.environ["BEDROCK_MODEL"]
REGION        = os.environ["REGION"]
LOG_BUCKET    = os.environ["LOG_BUCKET"]
ENVIRONMENT   = os.environ["ENVIRONMENT"]

bedrock = boto3.client("bedrock-runtime", region_name=REGION)
s3      = boto3.client("s3",              region_name=REGION)


def handler(event, context):
    """
    Triggered by EventBridge when an SSM maintenance window execution fails
    or a Patch Manager compliance state changes to NonCompliant/Failed.

    Flow:
      1. Extract failure context from the EventBridge event.
      2. Build a structured prompt and send it to Claude 3.5 Sonnet via Bedrock.
      3. Parse the AI-generated remediation report.
      4. Persist the report to S3 for audit / follow-up.
      5. Return a structured response (visible in Lambda logs and EventBridge DLQ).
    """
    print("patch-insights invoked:", json.dumps(event))

    # ── 1. Parse failure context ──────────────────────────────────────────────
    detail      = event.get("detail", {})
    source      = event.get("source", "unknown")
    detail_type = event.get("detail-type", "unknown")

    instance_id      = detail.get("instanceId",      detail.get("resourceId", "unknown"))
    patch_status     = detail.get("status",          detail.get("maintenanceWindowExecutionStatus", "FAILED"))
    window_id        = detail.get("maintenanceWindowId",        "unknown")
    window_exec_id   = detail.get("maintenanceWindowExecutionId", "unknown")
    failed_patches   = detail.get("installedRejectedCount", 0)
    missing_patches  = detail.get("missingCount",           0)
    failed_count     = detail.get("failedCount",            0)
    event_time       = event.get("time", datetime.now(timezone.utc).isoformat())

    # ── 2. Build Bedrock prompt ───────────────────────────────────────────────
    prompt = f"""You are an expert RHEL8 Linux systems engineer and AWS patch management specialist.

An automated RHEL8 patching job has FAILED. Analyse the failure details below and provide a
concise, actionable remediation report.

=== FAILURE DETAILS ===
Environment       : {ENVIRONMENT}
Instance ID       : {instance_id}
Patch Status      : {patch_status}
Event Source      : {source}
Event Type        : {detail_type}
Event Time        : {event_time}
Maintenance Window: {window_id}
Window Execution  : {window_exec_id}
Missing Patches   : {missing_patches}
Failed Patches    : {failed_count}
Rejected Patches  : {failed_patches}
Raw Event Detail  : {json.dumps(detail, indent=2)}

=== INSTRUCTIONS ===
Respond with a JSON object that contains exactly these keys:
{{
  "root_cause": "One-sentence likely root cause",
  "severity":   "LOW | MEDIUM | HIGH | CRITICAL",
  "immediate_actions": ["step1", "step2", ...],
  "dnf_commands": ["dnf command 1", "dnf command 2", ...],
  "aws_cli_commands": ["aws ssm ... command", ...],
  "preventive_measures": ["measure1", "measure2", ...],
  "escalate": true | false,
  "summary": "2-3 sentence executive summary"
}}

Rules:
- dnf_commands must be safe, idempotent, and suitable for RHEL8.
- aws_cli_commands must target instance {instance_id} in region {REGION}.
- Do NOT include markdown fences or any text outside the JSON object.
"""

    # ── 3. Invoke Bedrock (Claude 3.5 Sonnet) ────────────────────────────────
    bedrock_response = bedrock.invoke_model(
        modelId     = BEDROCK_MODEL,
        contentType = "application/json",
        accept      = "application/json",
        body        = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1500,
            "temperature": 0.1,
            "messages": [{
                "role":    "user",
                "content": [{"type": "text", "text": prompt}]
            }]
        })
    )

    raw_body   = json.loads(bedrock_response["body"].read())
    ai_text    = raw_body["content"][0]["text"].strip()

    try:
        analysis = json.loads(ai_text)
    except json.JSONDecodeError:
        analysis = {"raw_response": ai_text, "parse_error": "Claude did not return valid JSON"}

    # ── 4. Persist report to S3 ───────────────────────────────────────────────
    ts        = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    s3_key    = f"bedrock-patch-insights/{ENVIRONMENT}/{instance_id}/{ts}.json"
    report    = {
        "timestamp":    ts,
        "environment":  ENVIRONMENT,
        "instance_id":  instance_id,
        "patch_status": patch_status,
        "event":        event,
        "analysis":     analysis
    }

    s3.put_object(
        Bucket      = LOG_BUCKET,
        Key         = s3_key,
        Body        = json.dumps(report, indent=2),
        ContentType = "application/json"
    )
    print(f"Report saved → s3://{LOG_BUCKET}/{s3_key}")

    # ── 5. Return structured response ─────────────────────────────────────────
    return {
        "statusCode": 200,
        "instance_id":  instance_id,
        "patch_status": patch_status,
        "s3_report":    f"s3://{LOG_BUCKET}/{s3_key}",
        "analysis":     analysis
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

