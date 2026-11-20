output "web_url" {
  description = "Open in a browser (~1 min after apply)"
  value       = "http://${aws_instance.web.public_ip}"
}

output "instance_id" {
  description = "Connect without SSH: aws ssm start-session --target <id>"
  value       = aws_instance.web.id
}

output "bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}

output "vpc_id" {
  value = aws_vpc.main.id
}
