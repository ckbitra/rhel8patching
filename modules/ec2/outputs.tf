output "instance_ids" {
  description = "Map of EC2 instance IDs created by the module, keyed by the resource name"
  value = {
    for k, v in aws_instance.rhel8 :
    k => v.id
  }
}

output "public_ips" {
  description = "Map of public IP addresses assigned to each EC2 instance"
  value = {
    for k, v in aws_instance.rhel8 :
    k => v.public_ip
  }
}

