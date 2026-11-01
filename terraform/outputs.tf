output "web_public_ip" {
  description = "Public IP of the Web tier EC2 instance"
  value       = aws_instance.web.public_ip
}

output "app_private_ip" {
  description = "Private IP of the App tier EC2 instance"
  value       = aws_instance.app.private_ip
}

output "db_endpoint" {
  description = "RDS Postgres endpoint (host:port)"
  value       = aws_db_instance.postgres.endpoint
}

output "peering_connection_id" {
  description = "VPC peering connection between the App and Data VPCs"
  value       = aws_vpc_peering_connection.app_to_data.id
}

output "nat_gateway_public_ip" {
  description = "Public (Elastic) IP of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "frontend_url" {
  description = "URL to reach the NimbusCart frontend"
  value       = "http://${aws_instance.web.public_ip}"
}
