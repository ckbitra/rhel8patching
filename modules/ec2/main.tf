data "aws_ami" "rhel8" {
  most_recent = true
  owners      = ["309956199498"]  # ONLY Red Hat official (FREE)

  filter {
    name   = "name"
    values = ["RHEL-8.*x86_64*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "rhel8" {
  for_each = { for idx, role in var.instance_roles : "${var.environment}-instance-${idx}" => role }
  
  ami                         = data.aws_ami.rhel8.id
  instance_type               = "t2.micro"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm.name

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = {
    Name        = "rhel8-${each.key}"
    #Name        = "rhel8-${each.key}-instance-${each.value}"

    Environment = var.environment
    Role        = each.value
    #Role        = each.key
    PatchGroup  = "rhel8-${var.environment}"
  }
}

# SSM Instance Profile
resource "aws_iam_instance_profile" "ssm" {
  name = "${var.environment}-ssm-instance-profile"
  role = aws_iam_role.ssm_instance_role.name
}

resource "aws_iam_role" "ssm_instance_role" {
  name = "${var.environment}-ssm-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_instance_policy" {
  role       = aws_iam_role.ssm_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}