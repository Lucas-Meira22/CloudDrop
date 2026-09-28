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

output "bucket_name" {
  description = "App bucket name, goes into the app's BUCKET_NAME env var"
  value       = aws_s3_bucket.app.id
}

output "ecr_url" {
  description = "Image repository URL for docker push and the k8s Deployment"
  value       = aws_ecr_repository.app.repository_url
}