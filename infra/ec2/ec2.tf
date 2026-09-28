data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
  }

}

resource "aws_instance" "cloudDrop-instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"


}
