# Enabling AWS Bedrock Foundation Models

AWS Bedrock foundation models are **not enabled by default** — you must explicitly request access before any API call (`bedrock:InvokeModel`) will succeed.

## How to enable `anthropic.claude-3-5-sonnet-20240620-v1:0` in `us-east-2`

1. Open the AWS Console and navigate to **Amazon Bedrock**.
2. In the left sidebar, go to **Bedrock configurations → Model access**.
3. Click **Modify model access** (top right).
4. Find **Anthropic → Claude 3.5 Sonnet** and check the box.
5. Click **Next** → review → **Submit**.

Access is usually granted within a few minutes for Anthropic models. You'll see the status change from *Available* to *Request* → *Access granted*.

> **Important:** Make sure you do this in `us-east-2` (Ohio) specifically — model access is per-region. Enabling it in `us-east-1` does NOT carry over.

## What happens if you skip this?

Both integrations in this project will fail silently or with an error:
- The SSM Run Command shell script (`aws bedrock-runtime invoke-model ...`) will exit non-zero, the `jq` parse will fail, and `/tmp/patch_commands.sh` will be empty or missing — no patches get applied.
- The Lambda (`bedrock.invoke_model(...)`) will raise a `botocore.exceptions.ClientError` with `AccessDeniedException`, the function will return a 500, and no S3 report will be written.

## Quick CLI check to verify access is granted
```bash
aws bedrock list-foundation-models \
  --region us-east-2 \
  --query "modelSummaries[?modelId=='anthropic.claude-3-5-sonnet-20240620-v1:0'].[modelId,modelLifecycle]" \
  --output table
```
If access is granted you'll see the model listed. You can also check directly:
```bash
aws bedrock get-foundation-model \
  --model-identifier anthropic.claude-3-5-sonnet-20240620-v1:0 \
  --region us-east-2
```
A response without an `AccessDeniedException` confirms the model is enabled for your account in that region.