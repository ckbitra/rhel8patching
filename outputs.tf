output "vpc_id" { value = module.vpc.vpc_id }
output "instance_ids" { value = module.ec2.instance_ids }
output "public_ips" { value = module.ec2.public_ips }
output "maintenance_window_id" { value = module.patch_manager.maintenance_window_id }
output "ssm_document_name" { value = module.patch_manager.ssm_document_name }
output "patch_insights_lambda_arn" {
  description = "ARN of the patch‑insights Lambda function"
  value       = aws_lambda_function.patch_insights.arn
}

output "patch_failure_rule_arn" {
  description = "ARN of the EventBridge rule that fires on patch failures"
  value       = aws_cloudwatch_event_rule.patch_failure.arn
}