data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
  }

}

resource "aws_instance" "cloudDrop-instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public[0].id
  lifecycle {
    ignore_changes = [ami]
  }

  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # Installs k3s on first boot. Changing the script replaces the instance,
  # because user_data only runs once.

  user_data = templatefile("${path.module}/user_data.sh", {
    region       = var.region
    namespace    = var.project_name
    ecr_registry = split("/", aws_ecr_repository.app.repository_url)[0]
  })
  user_data_replace_on_change = true

  # IMDSv2 only (blocks SSRF credential theft). Hop limit 2 so pods, one
  # network hop further than the node, can still get the role's credentials.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # The default 8 GB fills up with k3s, container images and Prometheus
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-instance"
  }
}

#Security group for the EC2 instance

resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg"
  description = "Web traffic in, all traffic out. No SSH: access via SSM."
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP to Traefik ingress"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to Traefik ingress"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound: k3s install, ECR pulls, S3, SSM agent"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
  