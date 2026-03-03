variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "aws_profile" {
  type        = string
  default     = "dev"
  description = "AWS profile to use"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_roles" {
  description = "Number of instances per role"
  type        = map(number)
  default = {
    web = 1
    db  = 1
  }
}

variable "ssh_key_name" {
  description = "Existing SSH key pair name in AWS. If empty, a new key will be created and saved to {environment}-rhel8-key.pem"
  type        = string
  default     = ""
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket used for SSM/Bedrock logs"
  type        = string
  default     = "rhel8-patch-logs-dev"
}

variable "patch_insights_lambda_s3_bucket" {
  description = "Name of the S3 bucket containing the patch‑insights Lambda code"
  type        = string
  default     = "rhel8-patch-insights-dev"
}

variable "patch_insights_lambda_s3_key" {
  description = "S3 key for the patch‑insights Lambda zip"
  type        = string
  default     = "rhel8-patch-insights-dev"
}

variable "patch_insights_lambda_handler" {
  description = "Handler for the patch‑insights Lambda"
  type        = string
  default     = "index.handler" # adjust as needed
}

variable "patch_insights_lambda_runtime" {
  description = "Runtime for the patch‑insights Lambda"
  type        = string
  default     = "nodejs18.x" # or whatever you use
}

variable "patch_insights_event_pattern" {
  description = "EventBridge event pattern used by the patch‑failure rule"
  type        = any
  default     = {} # or omit default and pass it via tfvars/CLI
}