output "maintenance_window_id" { value = aws_ssm_maintenance_window.weekly_bedrock_patch.id }
output "ssm_document_name" { value = aws_ssm_document.bedrock_rhel8_patch.name }