## **Single Command Dashboard - Verify ALL RHEL8 Resources**

Instead of opening 10+ AWS Console tabs, use this **one PowerShell/AWS CLI script** to check **everything**:

### **1. Ultimate Resource Checker Script (`verify-rhel8.ps1`)**

```powershell
# Save as verify-rhel8.ps1 and run: .\verify-rhel8.ps1
Write-Host "🔍 RHEL8 Patching Lab Status Dashboard" -ForegroundColor Green
Write-Host "=" * 60

# 1. EC2 Instances (3x rhel8-dev-*)
aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],PrivateIpAddress,InstanceType]' --output table

# 2. SSM Managed Instances
aws ssm describe-instance-information --filters "Key=tag:Environment,Values=dev" --query 'InstanceInformationList[*].[InstanceId,PingStatus,PlatformType,PlatformName,PlatformVersion]' --output table

# 3. Patch Baselines
aws ssm describe-patch-baselines --query 'PatchBaselines[?Name==`rhel8-dev*`].[BaselineId,Name,OperatingSystem]' --output table

# 4. Maintenance Windows
aws ssm describe-maintenance-windows --query 'MaintenanceWindows[?Name==`RHEL8-dev*`].[WindowId,Name,Schedule]' --output table

# 5. Lambda Function
aws lambda list-functions --query "Functions[?FunctionName=='dev-patch-insights'].[FunctionName,Runtime,LastModified]" --output table

# 6. S3 Bucket
aws s3api list-buckets --query "Buckets[?Name=='dev-rhel8-patch-logs-*'].Name" --output table

# 7. CloudWatch Alarms (SSM metrics)
aws cloudwatch describe-alarms --query "MetricAlarms[?AlarmName=='dev-ssm-*'].[AlarmName,StateValue]" --output table

# 8. VPC & Subnet
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev" --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<YOUR_VPC_ID>" --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' --output table

Write-Host "`n✅ SUMMARY: Check Systems Manager → Fleet Manager for compliance!" -ForegroundColor Green
```

### **2. Terraform Outputs (Single Command)**
```bash
# Shows ALL created resource IDs/names
terraform output -json | jq .
```

### **3. One-Line Status Check**
```bash
# Copy-paste this single line for instant status
aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev" --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' --output table && aws ssm describe-instance-information --filters "Key=tag:Environment,Values=dev" --query 'InstanceInformationList[*].[InstanceId,PingStatus]' --output table && aws ssm describe-patch-baselines --query 'PatchBaselines[?OperatingSystem==`REDHAT_ENTERPRISE_LINUX_8`].[Name,BaselineId]' --output table
```

### **4. AWS Systems Manager Fleet Manager (BEST SINGLE PAGE)**
**AWS Console → Systems Manager → **Fleet Manager****
```
✅ Shows ALL your RHEL8 instances in ONE view
✅ Node status (Online/Offline) 
✅ Patch compliance status
✅ Maintenance window status
✅ Click any instance → SSM Session direct connect
```

### **5. Makefile for One-Command Checks**
```makefile
verify:
	aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev" --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' --output table && \
	aws ssm describe-instance-information --filters "Key=tag:Environment,Values=dev" --query 'InstanceInformationList[*].[InstanceId,PingStatus]' --output table

ssm-compliance:
	aws ssm get-compliance-summary-by-compliance-type --compliance-types Patch --query 'ComplianceSummaryList[].[ComplianceType,SeveritySummary[?Severity==`Critical`].NonCompliantCount]' --output table

lambda-status:
	aws lambda list-functions --query "Functions[?FunctionName=='dev-patch-insights'].FunctionName" --output table
```

### **6. CloudWatch Dashboard (Automated)**
**Add to your Terraform** (`dashboards.tf`):
```hcl
resource "aws_cloudwatch_dashboard" "rhel8_overview" {
  dashboard_name = "RHEL8-Patching-Dev"

  dashboard_body = jsonencode({
    widgets = [{
      type = "metric"
      properties = {
        metrics = [
          ["AWS/SSM", "FailedNodes", "PatchGroup", "rhel8-dev"],
          ["AWS/SSM", "CompliantNodes", "PatchGroup", "rhel8-dev"]
        ]
        period = 300
        title  = "RHEL8 Patch Compliance"
      }
    }]
  })
}
```

### **7. QUICKEST - Copy-Paste This:**
```bash
# INSTANT FULL STATUS (3 seconds)
echo "=== EC2 RHEL8 Instances ===" && aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev" --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' --output table && echo "=== SSM Status ===" && aws ssm describe-instance-information --filters "Key=tag:Environment,Values=dev" --query 'InstanceInformationList[*].[InstanceId,PingStatus,PlatformName]' --output table && echo "=== Patch Baselines ===" && aws ssm describe-patch-baselines --query 'PatchBaselines[?Name==`rhel8-dev*`].[Name,BaselineId]' --output table
```

## **RECOMMENDED WORKFLOW:**
```
1. Save verify-rhel8.ps1 → .\verify-rhel8.ps1     # Full dashboard
2. AWS Console → Systems Manager → Fleet Manager  # Live compliance view  
3. make verify                                    # Makefile automation
```

**One script replaces 10+ console tabs!** Your entire RHEL8 AIOps patching lab status in **3 seconds**. 