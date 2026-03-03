output "vpc_id" { value = module.vpc.vpc_id }
output "instance_ids" { value = module.ec2.instance_ids }
output "public_ips" { value = module.ec2.public_ips }

output "ssh_commands" {
  description = "SSH commands to connect to each RHEL8 instance (user: ec2-user)"
  value = {
    for k, ip in module.ec2.public_ips :
    k => "ssh -i ${local.ssh_key_path} ec2-user@${ip}"
  }
}

output "private_key_path" {
  description = "Path to the generated private key (only when ssh_key_name is empty)"
  value       = var.ssh_key_name == "" ? "${path.module}/${var.environment}-rhel8-key.pem" : null
}
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