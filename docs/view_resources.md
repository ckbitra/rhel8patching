# AWS Resource Management and Tagging Options

Yes — AWS Resource Groups & Tag Editor is exactly what you need. Since every resource in this project is tagged with `Environment=dev`, you can see all of them in one place.

## Option 1 — AWS Console (easiest)
- Navigate to: **Resource Groups & Tag Editor → Tag Editor**
- Set the following:
  - Regions: `us-east-2`
  - Resource types: *All* (or pick specific ones)
  - Tag key: `Environment` → Tag value: `dev`
- Click **Search resources**

You'll get a single table showing every EC2 instance, VPC, subnet, security group, SSM document, S3 bucket, Lambda, EventBridge rule, IAM role — everything tagged `Environment=dev`.

## Option 2 — AWS Resource Groups (saved view)
- Navigate to: **Resource Groups & Tag Editor → Create Resource Group**
- Choose **Tag-based**
- Add tag: `Environment = dev`
- Name it **rhel8-patching-dev**
- Save — it becomes a persistent dashboard you can revisit anytime.

## Option 3 — AWS Config
- Go to **AWS Config → Resources** which shows a full inventory with configuration history and compliance status.
- You can filter by tag and see how each resource's configuration has changed over time.

## Option 4 — CLI (instant)
```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Environment,Values=dev \
  --region us-east-2 \
  --query 'ResourceTagMappingList[*].[ResourceARN]' \
  --output table
```
This command returns every ARN tagged `Environment=dev` across all supported services in `us-east-2`.

# One caveat for this project
A few resources use a random suffix in their names (e.g., IAM roles like `dev-patch-insights-lambda-role-a1b2c3d4`) but they are still tagged `Environment=dev`, so Tag Editor will find them. The only resources that won't show up are things that don't support tagging—like IAM inline policies and EventBridge targets.