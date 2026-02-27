# Model Details

**Model used:** anthropic.claude-3-5-sonnet-20240620-v1:0 in region us-east-2

## Primary Integration — SSM Run Command (Active)

The main Bedrock usage is inside an SSM Run Command document defined in `modules/patch-manager/main.tf`. Every Saturday at 2AM UTC, a maintenance window triggers a shell script on each RHEL8 EC2 instance that performs the following steps:

1. Runs `dnf check-update --security` and saves available security updates to `/tmp/security_updates.txt`
2. Builds a prompt asking Claude to generate safe `dnf` patch commands (security-only, skip kernel, dry-run first)
3. Calls Bedrock via the AWS CLI (`aws bedrock-runtime invoke-model`) with the Anthropic Messages API format
4. Parses the JSON response with `jq` to extract the AI-generated shell commands
5. Executes those commands to apply patches
6. Runs a verification `dnf check-update --security`

Patch logs are stored in S3 under the prefix `bedrock-patch/{env}`.