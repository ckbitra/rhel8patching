
variable "environment" { type = string }
variable "s3_bucket_name" { type = string }
variable "region" { type = string }

variable "patch_insights_lambda_s3_bucket" {
  description = "S3 bucket containing the patch‑insights Lambda deployment package"
  type        = string
}

variable "patch_insights_lambda_s3_key" {
  description = "S3 key for the Lambda zip file"
  type        = string
}

variable "patch_insights_lambda_handler" {
  description = "Handler name for the Lambda (e.g. index.handler)"
  type        = string
  default     = "index.handler"
}

variable "patch_insights_lambda_runtime" {
  description = "Runtime for the Lambda function"
  type        = string
  default     = "python3.11"
}

variable "patch_insights_event_pattern" {
  description = "EventBridge pattern to catch patch‑window failures"
  type        = any
  default = {
    source = ["aws.ssm"]
    detail = {
      "maintenanceWindowExecutionStatus" = ["FAILED"]
    }
  }
}