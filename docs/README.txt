## Project Overview

This project creates the networking and compute resources for your RHEL‑8
patching environment, deploys a monitoring/insights Lambda, and wires EventBridge to
invoke that Lambda when patching maintenance windows fail. It’s a typical
Terraform configuration for an AWS automation workflow.


# Architecture Overview

```
VPC 
  ↓
RHEL8 EC2 (tagged PatchGroup) 
  ↓ 
SSM Agent 
  ↓ 
Bedrock Claude 3.5 Sonnet 
  ↓ 
Dynamic dnf security patches
  ↓ 
S3 logs. Runs every Saturday 2AM UTC.
```

## Step 1: Create S3 Buckets
```bash
aws s3 mb s3://dev-ssm-bedrock-logs --region us-east-2
aws s3 mb s3://prod-ssm-bedrock-logs --region us-east-2
```

## Step 2: Enable Bedrock Claude 3.5 Sonnet
```bash
aws bedrock request-model-access --model-arns arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-3-5-sonnet-20240620-v1:0
```

## Step 3: Deploy to Development Environment
```bash
terraform init
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

## Step 4: Deploy to Production Environment
```bash
terraform plan -var-file=environments/prod/terraform.tfvars
terraform apply -var-file=environments/prod/terraform.tfvars
"""

Notes:
# These commands work exactly as expected:
# dev
terraform plan -var-file=environments/dev/terraform.tfvars

#prod
terraform apply -var-file=environments/prod/terraform.tfvars
-------------
Verification
-------------
```
To manage the RHEL 8 patching project are categorized as follows:

1. Initial Tool & Environment Verification
These commands are used to ensure your local environment is correctly configured before starting the deployment:
terraform version: To check that your Terraform version is ≥ 1.0.
aws sts get-caller-identity: To verify your AWS CLI credentials.
aws configure get region: To confirm the default region for your AWS CLI.

2. Environment Deployment (Dev & Prod)
The sources outline a standard workflow for deploying both the development and production environments from their respective directories:

cd envs/dev (or cd envs/prod): To navigate to the appropriate Terraform root directory.
terraform init: To initialize the Terraform configuration and download necessary modules.

terraform plan -out=tfplan: To create an execution plan and save it to a file named tfplan.

terraform apply tfplan: To execute the planned changes and deploy the infrastructure.

3. Remote State Configuration (Optional)
If you choose to move from local state to an S3 and DynamoDB backend:
terraform init: This command is also used to initialize the new backend configuration after you have added the backend.tf file.

4. Summary of Workflow Actions
The sources also refer to "actions" that can be performed via the CLI, even if the specific full command syntax is truncated in some excerpts:

Manual Maintenance Window Execution: The guide notes that you can use the CLI to trigger a maintenance window manually, rather than using the AWS Console (Actions → Register run command).

Testing Lambda: You can manually invoke the Patch Insights Lambda (using the function name retrieved from your Terraform outputs) to test the Bedrock integration without waiting for a scheduled window

Step 5: Build and upload Patch Insights Lambda
• zip -r patch_insights.zip index.py
• aws s3 cp patch_insights.zip s3://…

The Lambda analyses the failure event, invokes Bedrock Claude to suggest remediation, then optionally re‑runs the maintenance window or posts to SNS/SSM.
```
Verification:
EC2 Console → 3 instances: rhel8-dev-instance-0/1/2
Systems Manager → Patch Manager → RHEL8-Dev baseline active
Lambda Console → dev-patch-insights → Ready
CloudWatch → Alarms on SSM/FailedNodes
---
1. EC2 Console: 3x rhel8-dev-instance-* running (t2.micro, 10GB EBS)
2. Systems Manager → Fleet Manager: All 3 instances "Online"
3. Patch Manager → Baselines: "rhel8-dev" baseline exists
4. Lambda Console: "dev-patch-insights-lambda-role-xyz" ready
