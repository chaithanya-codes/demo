output "jenkins_url" {
  description = "Jenkins UI. Port 8080 is restricted to jenkins_ui_cidr."
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_instance_id" {
  description = "Use this instance ID to connect with AWS Systems Manager Session Manager."
  value       = aws_instance.jenkins.id
}

output "ecr_repository_url" {
  description = "ECR repository receiving Jenkins-built images."
  value       = aws_ecr_repository.app.repository_url
}

output "jenkins_role_arn" {
  description = "EC2 instance role used by Jenkins through instance metadata."
  value       = aws_iam_role.jenkins.arn
}
