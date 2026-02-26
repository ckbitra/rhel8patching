resource "random_id" "role_suffix" {
  byte_length = 4
}

# IAM role for the patch‑insights Lambda
resource "aws_iam_role" "patch_insights_lambda_role" {
  name = "${var.environment}-patch-insights-lambda-${random_id.role_suffix.hex}"
  #name = "${var.environment}-patch-insights-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "patch_insights_lambda_basic" {
  role       = aws_iam_role.patch_insights_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# policy allowing lambda to invoke Bedrock, publish events, etc.
resource "aws_iam_role_policy" "patch_insights_bedrock" {
  name = "${var.environment}-patch-insights-bedrock"
  role = aws_iam_role.patch_insights_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"    # scope down as appropriate
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = "*"
      }
    ]
  })
}# Bedrock + SSM IAM Role


resource "aws_iam_role" "ssm_bedrock_role" {
  name = "${var.environment}-ssm-bedrock-role-${random_id.role_suffix.hex}"  # Add random_id suffix too

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ssm.amazonaws.com"
      }
    }]
  })
}


# Bedrock Invoke Permissions
resource "aws_iam_role_policy" "bedrock_access" {
  name = "${var.environment}-bedrock-policy"
  role = aws_iam_role.ssm_bedrock_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ]
      Resource = "arn:aws:bedrock:${var.region}::foundation-model/anthropic.claude-3-5-sonnet-20240620-v1:0"
    }]
  })
}

/*
resource "aws_iam_role_policy_attachment" "ssm_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonSSMMaintenanceWindowRole"
  ])

  role       = aws_iam_role.ssm_bedrock_role.name
  policy_arn = each.value
}
*/

# Weekly Maintenance Window (Sat 2AM UTC)
resource "aws_ssm_maintenance_window" "weekly_bedrock_patch" {
  name              = "${var.environment}-bedrock-patch-window"
  schedule          = "cron(0 2 ? * SAT *)"
  duration          = 2
  cutoff            = 1
  allow_unassociated_targets = true

  tags = {
    Name        = "${var.environment}-bedrock-patch-window"
    Environment = var.environment
  }
}

# Bedrock-Powered RHEL8 Patching Document
resource "aws_ssm_document" "bedrock_rhel8_patch" {
  name          = "${var.environment}-bedrock-rhel8-patch"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Bedrock Claude 3.5 Sonnet RHEL8 patching"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "bedrockPatch"
      inputs = {
        runCommand = [
          "echo '=== Bedrock RHEL8 Patching Started ==='",
          "dnf check-update --security > /tmp/security_updates.txt",
          "echo 'Current security updates:' && cat /tmp/security_updates.txt",
          # Bedrock Claude prompt for safe RHEL8 patching
          "cat > /tmp/bedrock_prompt.txt << 'EOF'",
          "You are RHEL8 patching expert. Analyze $$(cat /tmp/security_updates.txt)",
          "Generate ONLY executable dnf commands that:",
          "1. Install ONLY security updates",
          "2. Skip kernel updates (no reboot needed)",
          "3. Dry-run first with --assumeyes --dry-run",
          "4. Install if safe",
          "5. Output ONLY bash commands, no explanations",
          "EOF",
          # Invoke Claude 3.5 Sonnet via Bedrock
          "aws bedrock-runtime invoke-model \\",
          "  --model-id anthropic.claude-3-5-sonnet-20240620-v1:0 \\",
          "  --body '{\"anthropic_version\":\"bedrock-2023-05-31\",\"max_tokens\":1000,\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"$$(cat /tmp/bedrock_prompt.txt)\"}]}]}' \\",
          "  /tmp/bedrock_response.json",
          "jq -r '.content[0].text' /tmp/bedrock_response.json > /tmp/patch_commands.sh",
          "echo '=== Bedrock Generated Commands ==='",
          "cat /tmp/patch_commands.sh",
          "echo '=== Executing Safe Patch Commands ==='",
          "chmod +x /tmp/patch_commands.sh && /tmp/patch_commands.sh",
          "echo '=== Post-Patch Verification ==='",
          "dnf check-update --security"
        ]
      }
    }]
  })

  tags = {
    Name        = "${var.environment}-bedrock-rhel8-patch"
    Environment = var.environment
  }
}

# Register Bedrock Patch Task
# 1. FIRST: Create the maintenance window target
resource "aws_ssm_maintenance_window_target" "rhel8_target" {
  window_id     = aws_ssm_maintenance_window.weekly_bedrock_patch.id
  name          = "${var.environment}-rhel8-patch-target"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:PatchGroup"
    values = ["rhel8-${var.environment}"]
  }
}

# 2. SECOND: Reference target ID using WindowTargetIds
resource "aws_ssm_maintenance_window_task" "bedrock_patch_task" {
  window_id        = aws_ssm_maintenance_window.weekly_bedrock_patch.id
  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.rhel8_target.id]
  }
  task_arn         = aws_ssm_document.bedrock_rhel8_patch.arn
  task_type        = "RUN_COMMAND"
  priority         = 1
  max_concurrency  = "1"
  max_errors       = "0"
  service_role_arn = aws_iam_role.ssm_bedrock_role.arn

  task_invocation_parameters {
    run_command_parameters {
      comment          = "Bedrock Claude RHEL8 patching"
      output_s3_key_prefix = "bedrock-patch/${var.environment}"
    }
  }

  depends_on = [aws_ssm_maintenance_window_target.rhel8_target]
}
