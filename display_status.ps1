Write-Host "RHEL8 Patching Lab Status Dashboard" -ForegroundColor Green
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