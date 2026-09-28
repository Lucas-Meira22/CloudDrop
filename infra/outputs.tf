output "instance_id" {
  description = "EC2 instance ID, used by aws ssm start-session"
  value       = aws_instance.cloudDrop-instance.id
}

output "public_ip" {
  description = "Public IP of the app server (Traefik ingress on 80/443)"
  value       = aws_instance.cloudDrop-instance.public_ip
}

output "ssm_command" {
  description = "Opens a shell on the instance without SSH"
  value       = "aws ssm start-session --target ${aws_instance.cloudDrop-instance.id} --region ${var.region}"
}
