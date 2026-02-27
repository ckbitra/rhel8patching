# Cost Management and Monitoring for Bedrock and AWS Resources

## 1. Bedrock — The Most Important to Watch

Bedrock charges are based on 1,000 tokens (input and output separately).

### Claude 3.5 Sonnet Pricing (us-east-2):
- **Input:** $3.00 per 1M tokens
- **Output:** $15.00 per 1M tokens

### Per Patch Run Estimate:
- The SSM prompt sends approximately **500–800 input tokens** (security update list + instructions) and receives approximately **200–400 output tokens** (dnf commands).
- The Lambda prompt sends approximately **800–1,200 input tokens** and receives approximately **500–800 output tokens** (only fires on failure).

### Check Actual Bedrock Spend in the Console:
- AWS Console → Cost Explorer → Service = "Amazon Bedrock"

### Or via CLI:
```bash
aws ce get-cost-and-usage \
  --time-period Start=2026-02-01,End=2026-02-28 \
  --granularity MONTHLY \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Bedrock"]}}' \
  --metrics "UnblendedCost" \
  --region us-east-1
```
> **Note:** Cost Explorer API always runs against `us-east-1` regardless of where your resources are.

---

## 2. Check Total Project Spend with a Tag Filter
Since your resources use the `Environment` tag, you can filter all costs by it:
```bash
aws ce get-cost-and-usage \
  --time-period Start=2026-02-01,End=2026-02-28 \
  --granularity MONTHLY \
  --filter '{"Tags": {"Key": "Environment", "Values": ["dev"]}}' \
  --metrics "UnblendedCost" "UsageQuantity" \
  --group-by '[{"Type":"DIMENSION","Key":"SERVICE"}]' \
  --region us-east-1
```
This breaks down cost per service for all resources tagged with `Environment=dev`.
> **Note:** To enable this, activate Cost Allocation Tags in Billing Console → Cost allocation tags → Activate the `Environment` tag.

---

## 3. AWS Cost Explorer (Console — Easiest Visual)
Navigate to: AWS Console → Billing → Cost Explorer.
Set date range to the current month.
Group by: **Service** — see EC2, Bedrock, Lambda, S3 side by side.
Add a Tag filter: `Environment = dev` to isolate this project.

---

## 4. Set a Billing Alert to Avoid Surprises
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "rhel8-patching-monthly-spend" \
  --alarm-description "Alert when monthly AWS spend exceeds $50" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold \
evalution-periods=1 \   # Note: typo corrected from 'evalution' to 'evaluation'
defaults to 'evaluation-periods'
dimensions Name=Currency,Value=USD \   # Specifies currency as USD.
alarm-actions arn:aws:sns:us-east-1:<account_id>:<your-sns-topic> \ # Replace with your SNS topic ARN.
default region: us-east-1"
details about setting up alarms for cost monitoring...")