
Project flow, end-to-end:

---

# RHEL8 Automated Patching — Project Flow

## Phase 1: Provisioning (Terraform Apply)

When you run `terraform apply`, resources are created in this order:

### 1. VPC module
- **VPC** (10.0.0.0/16) with DNS hostnames/support  
- **Internet gateway**  
- **Public subnet** (10.0.1.0/24) in `${region}a`  
- **Route table** with default route to internet gateway  
- **Security group** for EC2 (SSH 22, HTTP 80, full egress)

### 2. SSH key (optional)
- **RSA key pair** (or use existing `ssh_key_name`)  
- **AWS key pair** registered  
- **Private key** written to `{env}-rhel8-key.pem` (if new key)

### 3. EC2 module
- **RHEL 8 AMI** selected (Red Hat 309956199498)  
- **EC2 instances** (t2.micro) in the public subnet, one per `instance_roles` entry  
- **IAM instance profile** with `AmazonSSMManagedInstanceCore`  
- **Tags**: `Name`, `Environment`, `Role`, `PatchGroup=rhel8-{env}`  
- Instances receive public IPs and the configured SSH key

### 4. Patch manager module
- **IAM roles**: `ssm_bedrock_role` (Bedrock), `patch_insights_lambda_role`  
- **SSM maintenance window**: Saturday 2AM UTC, 2h duration  
- **SSM Run Command document** (shell script that runs on instances)  
- **Maintenance window target**: instances with `PatchGroup=rhel8-{env}`  
- **Maintenance window task**: runs that document with `ssm_bedrock_role`

### 5. Root module
- **S3 bucket** for SSM/Bedrock logs  
- **Lambda function** `patch-insights` (inline Python)  
- **EventBridge rule** on SSM NonCompliant/Failed  
- **EventBridge target**: Lambda  
- **Lambda permission** for EventBridge

---

## Phase 2: Runtime — Weekly Patching (Saturday 2AM UTC)

### Step 1 — Maintenance window starts

- SSM triggers the maintenance window.  
- Targets: EC2 instances with `PatchGroup=rhel8-{env}`.  
- Runs the document `{env}-bedrock-rhel8-patch` as Run Command.

### Step 2 — On each EC2 instance

1. **Collect updates**  
   - `dnf check-update --security` → writes to `/tmp/security_updates.txt`

2. **Build prompt**  
   - Prompt instructs Claude to analyze the security update list and produce only executable `dnf` commands, security-only, no kernel, dry-run first.

3. **Call Bedrock**  
   - `aws bedrock-runtime invoke-model` → Claude 3.5 Sonnet  
   - Response saved to `/tmp/bedrock_response.json`

4. **Extract commands**  
   - `jq -r '.content[0].text' ...` → `/tmp/patch_commands.sh`

5. **Run commands**  
   - Execute `/tmp/patch_commands.sh` (AI-generated `dnf` commands)

6. **Verify**  
   - `dnf check-update --security` again

### Step 3 — Logging

- SSM Run Command sends stdout/stderr to S3:  
  `s3://{env}-rhel8-patch-logs-{account}/bedrock-patch/{env}/...`

---

## Phase 3: Failure Path (Lambda + Bedrock)

If a patching run is NonCompliant or Failed:

### Step 1 — EventBridge

- SSM emits events.  
- EventBridge rule matches `source=aws.ssm`, status `NonCompliant` or `Failed`.  
- Lambda `patch-insights` is invoked.

### Step 2 — Lambda

1. **Parse event**  
   - Extract instance ID, status, maintenance window IDs, patch counts.

2. **Build Bedrock prompt**  
   - Include failure context and ask for a structured JSON report (root cause, severity, actions, commands, etc.).

3. **Call Bedrock**  
   - `bedrock.invoke_model` (Claude 3.5 Sonnet).

4. **Parse response**  
   - Parse JSON (root_cause, severity, immediate_actions, dnf_commands, aws_cli_commands, etc.).

5. **Store report**  
   - S3: `s3://.../bedrock-patch-insights/{env}/{instanceId}/{timestamp}.json`

### Step 3 — Human follow-up

- Reports in S3 contain remediation steps and suggested commands.  
- RHEL8_PATCH_MONITORING can be used to monitor services and incidents.

---

## Summary Diagram

```
terraform apply
       │
       ├─► VPC + subnet + security group
       ├─► EC2 instances (RHEL8, tagged PatchGroup=rhel8-dev)
       ├─► SSM maintenance window + document + target + task
       ├─► Lambda + EventBridge rule
       └─► S3 log bucket

       ─── RUNTIME ───

Saturday 2AM UTC
       │
       ▼
SSM maintenance window triggers
       │
       ▼
On each EC2: dnf check-update → Bedrock (Claude) → dnf commands → execute
       │
       ├─► Success: logs → S3 bedrock-patch/{env}/
       │
       └─► Failure: EventBridge → Lambda → Bedrock analysis → S3 bedrock-patch-insights/{env}/{instance}/
```

---

## Main AWS Services

| Service    | Purpose                                      |
|-----------|-----------------------------------------------|
| **VPC**   | Network (subnet, security group, internet)    |
| **EC2**   | RHEL8 instances                               |
| **SSM**   | Run Command, maintenance window, document     |
| **Bedrock** | Claude 3.5 Sonnet (generate and analyze patches) |
| **Lambda**  | Failure analysis and remediation reports      |
| **EventBridge** | Trigger Lambda on patch failures          |
| **S3**    | Patch logs and Bedrock analysis reports       |
| **IAM**   | Roles for EC2, SSM, Lambda                    |
