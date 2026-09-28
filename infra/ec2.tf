# ---------- EC2 ----------

# Looks up the newest Ubuntu 26.04 image published by Canonical.
# A data block only reads from AWS, it creates nothing.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
  }
}

# Disabled until the VPC is up: without subnet_id it would launch in the
# default VPC. When re-enabling, add subnet_id = aws_subnet.public[0].id
# and a security group.
# resource "aws_instance" "cloudDrop-instance" {
#   ami           = data.aws_ami.ubuntu.id
#   instance_type = "t3.small"
# }

# ---------- VPC and Subnets ----------

# Lists the availability zones (separate data centers) in the region.
data "aws_availability_zones" "available" {
  state = "available"
}

# Keeps the first two AZs, one per subnet.
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# The private network everything lives in. 10.0.0.0/16 = 65,536 IPs.
# DNS settings let instances get hostnames and resolve AWS endpoints.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "clouddrop-vpc" }
}

# Two subnets, one per AZ: 10.0.1.0/24 and 10.0.2.0/24 (256 IPs each).
# Instances launched here get a public IP automatically.
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 1)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
}

# The VPC's door to the internet.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Routing rules: any traffic not meant for the VPC (0.0.0.0/0) goes out
# through the internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "clouddrop-route-table" }
}

# Attaches the public route table to each subnet. Without this the subnets
# use the VPC's main route table, which has no route to the internet.
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Lets the VPC reach S3 through AWS's private network instead of the
# internet. Gateway endpoints for S3 are free.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id]
}
