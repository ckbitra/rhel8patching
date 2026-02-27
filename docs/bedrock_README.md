# RHEL8 Automated Patching with AWS Bedrock — Full Architecture

## Overview

This project automates RHEL8 security patching using **AWS Bedrock (Claude 3.5 Sonnet)** as an
AI decision engine. Bedrock is used in two distinct integration points:

| Integration | Trigger | Status |
|---|---|---|
| **Primary — SSM Run Command** | Weekly maintenance window (Sat 2AM UTC) | Active |
| **Secondary — Lambda Failure Analysis** | EventBridge on patch failure / NonCompliant | Active |

**Model:** `anthropic.claude-3-5-sonnet-20240620-v1:0`  
**Region:** `us-east-2`

---

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     WEEKLY PATCH CYCLE (Saturday 2AM UTC)               │
└─────────────────────────────────────────────────────────────────────────┘

  EventBridge Scheduler
        │
        ▼
  SSM Maintenance Window  ──── service role: ssm_bedrock_role
  ({env}-bedrock-patch-window)       (bedrock:InvokeModel scoped to model ARN)
        │
        │  targets: EC2 instances tagged  PatchGroup=rhel8-{env}
        ▼
  SSM Run Command Document
  ({env}-bedrock-rhel8-patch)
        │
        │  runs shell script on EACH matched EC2 instance
        ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │  ON EACH RHEL8 EC2 INSTANCE                                         │
  │                                                                     │
  │  1. dnf check-update --security  →  /tmp/security_updates.txt      │
  │                                                                     │
  │  2. Build Claude prompt:                                            │
  │       "You are RHEL8 patching expert.                               │
  │        Analyze <security_updates>.                                  │
  │        Generate ONLY executable dnf commands that:                  │
  │          - Install ONLY security updates                            │
  │          - Skip kernel updates (no reboot needed)                   │
  │          - Dry-run first with --assumeyes --dry-run                 │
  │          - Install if safe                                          │
  │        Output ONLY bash commands, no explanations."                 │
  │                                                                     │
  │  3. aws bedrock-runtime invoke-model                                │
  │       --model-id anthropic.claude-3-5-sonnet-20240620-v1:0         │
  │       --body '{"anthropic_version":"bedrock-2023-05-31",            │
  │                "max_tokens":1000, "messages":[...]}'                │
  │       /tmp/bedrock_response.json                                    │
  │                                                                     │
  │  4. jq -r '.content[0].text' /tmp/bedrock_response.json            │
  │       → /tmp/patch_commands.sh                                      │
  │                                                                     │
  │  5. chmod +x /tmp/patch_commands.sh && /tmp/patch_commands.sh      │
  │       (executes AI-generated dnf commands)                          │
  │                                                                     │
  │  6. dnf check-update --security  (post-patch verification)         │
  └─────────────────────────────────────────────────────────────────────┘
        │
        │  SSM streams stdout/stderr to S3
        ▼
  S3: {env}-rhel8-patch-logs-{account_id}
      └── bedrock-patch/{env}/...   (raw SSM command output)


┌─────────────────────────────────────────────────────────────────────────┐
│              FAILURE PATH — Lambda Bedrock Analysis                      │
└─────────────────────────────────────────────────────────────────────────┘

  SSM reports NonCompliant or Failed status
        │
        ▼
  EventBridge Rule
  ({env}-patch-failure-rule)
  pattern: source=aws.ssm, detail.status=[NonCompliant, Failed]
        │
        ▼
  Lambda: {env}-patch-insights
  (role: lambda_role  →  lambda_bedrock_s3 inline policy)
        │
        │  1. Parse EventBridge event:
        │       instanceId, status, maintenanceWindowId,
        │       missingCount, failedCount, installedRejectedCount
        │
        │  2. Build structured prompt for Claude:
        │       "You are an expert RHEL8 systems engineer.
        │        An automated patching job FAILED.
        │        Analyse these details: <failure context>
        │        Respond with JSON containing:
        │          root_cause, severity, immediate_actions,
        │          dnf_commands, aws_cli_commands,
        │          preventive_measures, escalate, summary"
        │
        │  3. bedrock_client.invoke_model(
        │       modelId="anthropic.claude-3-5-sonnet-20240620-v1:0",
        │       temperature=0.1, max_tokens=1500
        │     )
        │
        │  4. Parse JSON response from Claude
        │
        │  5. s3.put_object(
        │       Bucket=LOG_BUCKET,
        │       Key="bedrock-patch-insights/{env}/{instanceId}/{ts}.json"
        │     )
        │
        ▼
  S3: {env}-rhel8-patch-logs-{account_id}
      └── bedrock-patch-insights/{env}/{instanceId}/{timestamp}.json
              {
                "timestamp": "...",
                "environment": "dev",
                "instance_id": "i-0abc...",
                "patch_status": "FAILED",
                "event": { ...raw EventBridge event... },
                "analysis": {
                  "root_cause": "...",
                  "severity": "HIGH",
                  "immediate_actions": ["..."],
                  "dnf_commands": ["dnf update --security ..."],
                  "aws_cli_commands": ["aws ssm send-command ..."],
                  "preventive_measures": ["..."],
                  "escalate": false,
                  "summary": "..."
                }
              }
```

---

## IAM Roles & Permissions

### `ssm_bedrock_role` — used by SSM Maintenance Window

| Permission | Resource |
|---|---|
| `bedrock:InvokeModel` | `arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-3-5-sonnet-20240620-v1:0` |
| `bedrock:InvokeModelWithResponseStream` | same |

### `lambda_role` — used by `{env}-patch-insights` Lambda

| Permission | Resource |
|---|---|
| CloudWatch Logs (write) | `AWSLambdaBasicExecutionRole` managed policy |
| `bedrock:InvokeModel` | `arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-3-5-sonnet-20240620-v1:0` |
| `bedrock:InvokeModelWithResponseStream` | same |
| `s3:PutObject`, `s3:GetObject` | `arn:aws:s3:::${env}-rhel8-patch-logs-*/*` |

---

## Key Files

| File | Purpose |
|---|---|
| `modules/patch-manager/main.tf` | SSM maintenance window, Run Command document, `ssm_bedrock_role` |
| `main.tf` | Lambda function with full Bedrock implementation, EventBridge rule & target |
| `iam.tf` | `lambda_role` with `lambda_bedrock_s3` inline policy |
| `variables.tf` | `region`, `environment`, `s3_bucket_name` and Lambda config variables |
| `outputs.tf` | Exposes `patch_insights_lambda_arn` and `patch_failure_rule_arn` |

---

## Lambda Environment Variables

| Variable | Value |
|---|---|
| `LOG_BUCKET` | `{env}-rhel8-patch-logs-{account_id}` (Terraform-managed S3 bucket) |
| `BEDROCK_MODEL` | `anthropic.claude-3-5-sonnet-20240620-v1:0` |
| `REGION` | `us-east-2` |
| `ENVIRONMENT` | `dev` (or whatever `var.environment` is set to) |

---

## S3 Report Structure

All Bedrock-related output lands in the same S3 bucket under separate prefixes:

```
{env}-rhel8-patch-logs-{account_id}/
├── bedrock-patch/{env}/                        ← SSM Run Command stdout/stderr
│   └── {instance_id}/{command_id}/...
└── bedrock-patch-insights/{env}/               ← Lambda Bedrock analysis reports
    └── {instance_id}/
        └── 20260227T020512Z.json
```

---

## Deployment Notes

1. The Lambda code is bundled inline via `archive_file` — no external zip or S3 upload needed.
2. The Lambda runtime is `python3.12` using only the AWS SDK (`boto3`) which is pre-installed in the Lambda execution environment.
3. The Lambda timeout is set to **60 seconds** to accommodate Bedrock API latency.
4. To test the Lambda manually, send a synthetic EventBridge event:

```json
{
  "source": "aws.ssm",
  "detail-type": "Patch Manager Compliance State Change",
  "time": "2026-02-27T02:05:00Z",
  "detail": {
    "instanceId": "i-0123456789abcdef0",
    "status": "NonCompliant",
    "maintenanceWindowId": "mw-0abc123",
    "missingCount": 3,
    "failedCount": 1,
    "installedRejectedCount": 0
  }
}
```
